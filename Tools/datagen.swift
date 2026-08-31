// Fetches the GitHub data the board draws and writes Sources/Site/Generated.swift.
// Run by hand when the numbers should move:
//
//     swift Tools/datagen.swift
//
// Date handling and networking live here, on the host, so the wasm module only
// ever sees plain arrays.

import Foundation

let handle = "stefanceriu"
let firstYear = 2008

func get(_ url: String) -> Data {
    guard let u = URL(string: url) else { exit(1) }
    var request = URLRequest(url: u)
    request.setValue("stefanceriu-site-datagen", forHTTPHeaderField: "User-Agent")
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

    var payload: Data?
    let wait = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: request) { data, _, _ in
        payload = data
        wait.signal()
    }.resume()
    wait.wait()

    guard let d = payload else {
        FileHandle.standardError.write("failed: \(url)\n".data(using: .utf8)!)
        exit(1)
    }
    return d
}

/// Unauthenticated search allows ten calls a minute, so every search waits.
func search(_ query: String, page: Int = 1) -> [String: Any] {
    let escaped = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
    let url = "https://api.github.com/search/issues?q=\(escaped)&per_page=100&page=\(page)"
    let json = (try? JSONSerialization.jsonObject(with: get(url))) as? [String: Any] ?? [:]
    Thread.sleep(forTimeInterval: 7)
    if let message = json["message"] as? String {
        FileHandle.standardError.write("  search refused: \(message)\n".data(using: .utf8)!)
    }
    return json
}

func matches(_ pattern: String, in text: String) -> [[String]] {
    let re = try! NSRegularExpression(pattern: pattern)
    let ns = text as NSString
    return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { m in
        (0..<m.numberOfRanges).map { i in
            m.range(at: i).location == NSNotFound ? "" : ns.substring(with: m.range(at: i))
        }
    }
}

// MARK: - Contributions

struct Day {
    let date: Date
    let level: Int
    let count: Int
}

let iso: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = TimeZone(identifier: "UTC")
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
}()

// The calendar cells carry the date and the level; the exact per-day count only
// appears in the tooltip, tied back to the cell by id.
func days(from html: String) -> [Day] {
    var counts: [String: Int] = [:]
    for m in matches("<tool-tip[^>]*for=\"([^\"]+)\"[^>]*>([^<]*)</tool-tip>", in: html) {
        let text = m[2]
        let n = matches("^([0-9,]+) contribution", in: text).first
            .map { Int($0[1].replacingOccurrences(of: ",", with: "")) ?? 0 } ?? 0
        counts[m[1]] = n
    }

    var out: [Day] = []
    for m in matches("<td[^>]*id=\"([^\"]+)\"[^>]*data-date=\"([0-9-]+)\"[^>]*data-level=\"([0-9]+)\"", in: html) {
        guard let date = iso.date(from: m[2]) else { continue }
        out.append(Day(date: date, level: Int(m[3]) ?? 0, count: counts[m[1]] ?? 0))
    }
    // attribute order is not guaranteed, so try the other arrangement too
    if out.isEmpty {
        for m in matches("<td[^>]*data-date=\"([0-9-]+)\"[^>]*id=\"([^\"]+)\"[^>]*data-level=\"([0-9]+)\"", in: html) {
            guard let date = iso.date(from: m[1]) else { continue }
            out.append(Day(date: date, level: Int(m[3]) ?? 0, count: counts[m[2]] ?? 0))
        }
    }
    return out.sorted { $0.date < $1.date }
}

FileHandle.standardError.write("fetching contributions…\n".data(using: .utf8)!)

let recent = days(from: String(data: get("https://github.com/users/\(handle)/contributions"), encoding: .utf8) ?? "")
guard !recent.isEmpty else {
    FileHandle.standardError.write("no contribution cells parsed — GitHub markup changed\n".data(using: .utf8)!)
    exit(1)
}

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "UTC")!
let thisYear = calendar.component(.year, from: Date())

// Lay the recent year out the way the share chart reads it: a column per week,
// seven rows, Monday at the top.
var weekCounts: [[Int]] = []
var weekStarts: [String] = []
var columnCounts = [Int](repeating: 0, count: 7)
var columnStart: String?
var columnHasDays = false
for day in recent {
    // .weekday is 1 = Sunday, so shift it round to make Monday the week's first row
    let weekday = (calendar.component(.weekday, from: day.date) + 5) % 7
    if weekday == 0 && columnHasDays {
        weekCounts.append(columnCounts); weekStarts.append(columnStart ?? "")
        columnCounts = [Int](repeating: 0, count: 7)
        columnStart = nil
        columnHasDays = false
    }
    if columnStart == nil { columnStart = iso.string(from: day.date) }
    columnCounts[weekday] = day.count
    columnHasDays = true
}
if columnHasDays {
    weekCounts.append(columnCounts); weekStarts.append(columnStart ?? "")
}

let emptyWeeks = weekCounts.filter { $0.reduce(0, +) == 0 }.count
FileHandle.standardError.write("  weeks with no contributions: \(emptyWeeks)\n".data(using: .utf8)!)

// MARK: - Repositories

FileHandle.standardError.write("fetching repositories…\n".data(using: .utf8)!)

let reposJSON = try! JSONSerialization.jsonObject(
    with: get("https://api.github.com/users/\(handle)/repos?per_page=100&sort=updated")) as! [[String: Any]]
let repos = reposJSON.filter { !($0["fork"] as? Bool ?? false) }

// MARK: - Work in the orgs

// Merged pull requests authored in the two organisations. Search caps a single
// query at 1000 results, so the totals come from the counts rather than from
// walking the items, and the per-repository figures are asked for one at a time.
FileHandle.standardError.write("fetching org pull requests…\n".data(using: .utf8)!)

let orgs = ["element-hq", "matrix-org"]
var orgTotals: [(org: String, count: Int)] = []
var seenRepos: Set<String> = []

for org in orgs {
    let base = "author:\(handle) org:\(org) type:pr is:merged"
    let head = search(base)
    let total = head["total_count"] as? Int ?? 0
    orgTotals.append((org, total))
    FileHandle.standardError.write("  \(org): \(total) merged\n".data(using: .utf8)!)

    // Sample newest and oldest to catch repositories from both ends of the
    // history. Sorting is a URL parameter, not a search qualifier — written as
    // `sort:created-asc` inside the query it is ignored, both passes come back
    // ranked the same way, and whole repositories go missing at random.
    for order in ["desc", "asc"] {
        let url = "https://api.github.com/search/issues?q="
            + (base.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
            + "&sort=created&order=\(order)&per_page=100&page=1"
        let json = (try? JSONSerialization.jsonObject(with: get(url))) as? [String: Any] ?? [:]
        Thread.sleep(forTimeInterval: 7)
        for item in json["items"] as? [[String: Any]] ?? [] {
            if let repoURL = item["repository_url"] as? String,
               let name = repoURL.components(separatedBy: "/repos/").last {
                seenRepos.insert(name)
            }
        }
    }
}

var repoPRs: [(repo: String, count: Int)] = []
for repo in seenRepos.sorted() {
    let json = search("author:\(handle) repo:\(repo) type:pr is:merged")
    let count = json["total_count"] as? Int ?? 0
    if count > 0 {
        repoPRs.append((repo, count))
        FileHandle.standardError.write("  \(repo): \(count)\n".data(using: .utf8)!)
    }
}
repoPRs.sort { $0.count > $1.count }

// MARK: - One list of repositories

// The board sorts everything by stars, so the repositories worked on inside the
// organisations join the owned ones in a single list.
FileHandle.standardError.write("fetching org repositories…\n".data(using: .utf8)!)

func escaped(_ text: String) -> String {
    text.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: " ")
}

struct Entry {
    let full: String
    let blurb: String
    let stars: Int
    let forks: Int
    let language: String
    let prs: Int
}

var entries: [Entry] = []

for r in repos {
    guard let name = r["name"] as? String else { continue }
    entries.append(Entry(
        full: "\(handle)/\(name)",
        blurb: (r["description"] as? String) ?? "",
        stars: r["stargazers_count"] as? Int ?? 0,
        forks: r["forks_count"] as? Int ?? 0,
        language: (r["language"] as? String) ?? "",
        prs: 0))
}

// A single merged pull request is not involvement, and on a chart sorted by
// stars a big repository touched once outranks the ones actually worked on.
let minimumPRs = 2

for (full, prs) in repoPRs where prs >= minimumPRs {
    let json = (try? JSONSerialization.jsonObject(with: get("https://api.github.com/repos/\(full)"))) as? [String: Any] ?? [:]
    guard let stars = json["stargazers_count"] as? Int else {
        FileHandle.standardError.write("  skipped \(full)\n".data(using: .utf8)!)
        continue
    }
    entries.append(Entry(
        full: full,
        blurb: (json["description"] as? String) ?? "",
        stars: stars,
        forks: json["forks_count"] as? Int ?? 0,
        language: (json["language"] as? String) ?? "",
        prs: prs))
    FileHandle.standardError.write("  \(full): \(stars) stars\n".data(using: .utf8)!)
}

entries.sort { $0.stars > $1.stars }

// MARK: - Emit

func swiftArray(_ rows: [[Int]]) -> String {
    rows.map { "[" + $0.map(String.init).joined(separator: ",") + "]" }.joined(separator: ", ")
}

let out = """
// Generated by Tools/datagen.swift — do not edit by hand.
// Fetched \(iso.string(from: Date())).

enum GitHubData {
    /// A column per week, seven rows with Monday at the top.
    static let calendarCounts: [[Int]] = [\(swiftArray(weekCounts))]

    /// The date each column starts on, aligned with the array above.
    static let calendarWeekStarts = [\(weekStarts.map { "\"\($0)\"" }.joined(separator: ", "))]

    static let repos: [Repo] = [
\(entries.map { "        Repo(full: \"\($0.full)\", blurb: \"\(escaped($0.blurb))\", stars: \($0.stars), forks: \($0.forks), language: \"\(escaped($0.language))\", prs: \($0.prs)),"
    }.joined(separator: "\n"))
    ]

    static let orgTotals: [(org: String, count: Int)] = [\(orgTotals.map { "(\"\($0.org)\", \($0.count))" }.joined(separator: ", "))]

    static let orgPullRequests: [(repo: String, count: Int)] = [\(repoPRs.map { "(\"\($0.repo)\", \($0.count))" }.joined(separator: ", "))]
}

"""

let dest = URL(fileURLWithPath: "Sources/Site/Generated.swift")
try! out.write(to: dest, atomically: true, encoding: .utf8)
FileHandle.standardError.write("wrote \(dest.path) — \(weekCounts.count) weeks, \(entries.count) repositories\n".data(using: .utf8)!)
