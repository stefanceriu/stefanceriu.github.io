import JavaScriptKit

// The board is drawn once from `Profile`, then a click on a bar or a role
// swaps the panel and moves the accent. Nothing else on the page changes, so
// the listeners are bound once and never rebound.

let document = JSObject.global.document.object!

var listeners: [JSClosure] = []

func grouped(_ n: Int) -> String {
    let digits = Array(String(n))
    var out = ""
    for (i, d) in digits.enumerated() {
        if i > 0 && (digits.count - i) % 3 == 0 { out.append(",") }
        out.append(d)
    }
    return out
}

// MARK: - Cells

func statsHTML() -> String {
    Profile.stats.map { stat in
        "<div class=\"stat\"><i></i><b>\(stat.value)</b><span class=\"label\">\(stat.label)</span></div>"
    }.joined()
}

func barsHTML() -> String {
    // Every repository that has been starred at least once; the rest would be
    // empty bars.
    let top = GitHubData.repos.filter { $0.stars > 0 }
    let peak = top.first?.stars ?? 1
    return top.map { repo in
        let width = repo.stars * 100 / peak
        let owner = repo.owned ? "" : "<span class=\"who\">\(repo.owner)/</span>"
        // Stars and forks measure a repository you own. In one you contributed
        // to, they measure the project rather than your part in it, so those
        // rows count your merged pull requests instead.
        var stats: [String] = []
        if !repo.language.isEmpty { stats.append(repo.language) }
        if repo.owned {
            stats.append("<b>\(grouped(repo.stars))</b> stars")
            stats.append("<b>\(grouped(repo.forks))</b> forks")
        } else {
            stats.append("<b>\(grouped(repo.prs))</b> merged PRs")
        }
        return """
        <div class="bar">\
        <a class="nm" href="\(repo.contributions)">\(owner)<b>\(repo.name)</b></a>\
        <span class="desc">\(repo.blurb)</span>\
        <span class="track"><i style="width:\(width)%"></i></span>\
        <span class="n">\(stats.joined(separator: " · "))</span>\
        </div>
        """
    }.joined()
}

func rolesHTML() -> String {
    Profile.roles.map { role in
        """
        <div class="role">\
        \(role.title.map { "\($0) · " } ?? "")\(role.org)\
        \(role.when.map { "<span class=\"when\">\($0)</span>" } ?? "")\
        </div>
        """
    }.joined()
}

func boardHTML() -> String {
    """
    <div class="board">
      <div class="cell head">
        <h1>\(Profile.firstName) <em>\(Profile.lastName)</em></h1>
        <span class="label">\(Profile.headline)</span>
      </div>
      <div class="cell fig">
        <p class="standfirst">\(Profile.bio)</p>
        <div class="stats">\(statsHTML())</div>
      </div>
      <div class="cell say">
        \(Profile.lede.map { "<p class=\"lede\">\($0)</p>" }.joined())
        <span class="label where">where</span>
        <div class="column">
          <div class="wall">\(rolesHTML())</div>
          <div class="steps" aria-hidden="true"><span class="step">&#9650;</span><div class="rail"><i></i></div><span class="step">&#9660;</span></div>
        </div>
      </div>
      <div class="cell chart">
        <div class="top">
          <p class="readout">stars per repository</p>
        </div>
        <div class="column">
          <div class="bars">\(barsHTML())</div>
          <div class="steps" aria-hidden="true"><span class="step">&#9650;</span><div class="rail"><i></i></div><span class="step">&#9660;</span></div>
        </div>
      </div>
      <div class="cell graphs">
        <div class="top">
          <p class="readout shareout">\(shareReadout())</p>
          <div class="pager">
            <span class="says">change day</span>
            <button class="arrow" type="button" data-band="-1" title="previous day">&#9664;</button>
            <span class="at"><b class="bandnum">\(band + 1)</b>/7</span>
            <button class="arrow" type="button" data-band="1" title="next day">&#9654;</button>
          </div>
        </div>
        <div class="plot chartplot">\(shareChartHTML())</div>
        <div class="top gtop">
          <p class="readout">merged pull requests</p>
        </div>
        <div class="plot gplot">\(pullsHTML())</div>
      </div>
      <div class="cell foot">
        <a href="\(Profile.links[0].url)">\(Profile.links[0].label)</a>
        <span class="label colophon">\(Profile.colophon)<svg class="swift" viewBox="5.96 8.43 44.84 40.12" aria-hidden="true"><path d="m47.06 36.66-.004-.004c.066-.224.134-.446.191-.675 2.465-9.821-3.55-21.432-13.731-27.546 4.461 6.048 6.434 13.374 4.681 19.78-.156.571-.344 1.12-.552 1.653-.225-.148-.51-.316-.89-.527 0 0-10.127-6.252-21.103-17.312-.288-.29 5.852 8.777 12.822 16.14-3.284-1.843-12.434-8.5-18.227-13.802.712 1.187 1.558 2.33 2.489 3.43C17.573 23.932 23.882 31.5 31.44 37.314c-5.31 3.25-12.814 3.502-20.285.003a30.646 30.646 0 0 1-5.193-3.098c3.162 5.058 8.033 9.423 13.96 11.97 7.07 3.039 14.1 2.833 19.336.05l-.004.007c.024-.016.055-.032.08-.047.214-.116.428-.234.636-.358 2.516-1.306 7.485-2.63 10.152 2.559.654 1.27 2.041-5.46-3.061-11.74z"/></svg></span>
        <a href="\(Profile.links[1].url)">\(Profile.links[1].label)</a>
      </div>
    </div>
    """
}

// MARK: - Charts

// Merged pull requests in the two organisations. These are static rows rather
// than the interactive repo bars, so they are divs and carry no data-repo.
func pullsHTML() -> String {
    let top = Array(GitHubData.orgPullRequests.prefix(4))
    let peak = top.first?.count ?? 1
    let rows = top.map { entry in
        let short = String(entry.repo.split(separator: "/").last ?? Substring(entry.repo))
        let width = peak > 0 ? entry.count * 100 / peak : 0
        return """
        <div class="bar" title="\(entry.repo)">\
        <span class="nm">\(short)</span>\
        <span class="track"><i style="width:\(width)%"></i></span>\
        <span class="n">\(grouped(entry.count))</span>\
        </div>
        """
    }.joined()
    let total = GitHubData.orgTotals.reduce(0) { $0 + $1.count }
    let hidden = GitHubData.orgPullRequests.count - top.count
    let more = hidden > 0 ? " · +\(hidden) smaller" : ""
    let orgs = GitHubData.orgTotals.map { "\($0.org) <b>\(grouped($0.count))</b>" }.joined(separator: " · ")
    return """
    <div class="bars plain">\(rows)</div>
    <p class="note">\(orgs) · <b>\(grouped(total))</b> total\(more)</p>
    """
}

// MARK: - The weekly share chart

let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

/// One grey ramp for the days that are not chosen; the accent marks the one that is.
let dayFills = ["#e6e6e6", "#d8d8d8", "#c6c6c6", "#b2b2b2", "#9c9c9c", "#868686", "#6e6e6e"]

var band = 0          // which weekday is accented; Monday by default
var cursorWeek = -1   // which week the pointer is over, -1 for none

/// Weeks that recorded nothing are left out. A week with no contributions has
/// no share to divide up, so it can only ever be a hole in the ribbon.
let liveWeeks: [(start: String, counts: [Int])] =
    zip(GitHubData.calendarWeekStarts, GitHubData.calendarCounts)
        .filter { $0.1.reduce(0, +) > 0 }
        .map { (start: $0.0, counts: $0.1) }

func percent(_ share: Double) -> String {
    let tenths = Int((share * 1000).rounded())
    return "\(tenths / 10).\(tenths % 10)"
}

func shareOf(week: Int, day: Int) -> Double {
    guard week >= 0, week < liveWeeks.count else { return 0 }
    let counts = liveWeeks[week].counts
    let total = counts.reduce(0, +)
    return total > 0 ? Double(counts[day]) / Double(total) : 0
}

func averageShare(day: Int) -> Double {
    guard !liveWeeks.isEmpty else { return 0 }
    return (0..<liveWeeks.count).reduce(0.0) { $0 + shareOf(week: $1, day: day) } / Double(liveWeeks.count)
}

func shareChartHTML() -> String {
    let n = liveWeeks.count
    guard n > 1 else { return "" }

    let width = 1000.0, height = 300.0
    func px(_ i: Int) -> Double { Double(i) / Double(n - 1) * width }
    func fmt(_ v: Double) -> String { String(Int(v.rounded())) }

    var lower = [Double](repeating: 0, count: n)
    var bands = ""
    for day in 0..<7 {
        var upper = [Double](repeating: 0, count: n)
        for w in 0..<n {
            upper[w] = lower[w] + shareOf(week: w, day: day)
        }
        // straight segments, week to week — the shape is the data, not a curve
        let top = (0..<n).map { "\(fmt(px($0))),\(fmt(height - upper[$0] * height))" }
        let bottom = (0..<n).reversed().map { "\(fmt(px($0))),\(fmt(height - lower[$0] * height))" }
        let fill = day == band ? "var(--accent)" : dayFills[day]
        bands += "<path d=\"M\(top.joined(separator: " L")) L\(bottom.joined(separator: " L")) Z\""
            + " fill=\"\(fill)\" stroke=\"var(--ground)\" stroke-width=\"1\" vector-effect=\"non-scaling-stroke\"/>"
        lower = upper
    }

    var rules = ""
    for share in [0.25, 0.5, 0.75] {
        let y = fmt(height - share * height)
        rules += "<line x1=\"0\" x2=\"1000\" y1=\"\(y)\" y2=\"\(y)\" stroke=\"var(--ink)\""
            + " stroke-opacity=\"0.45\" stroke-dasharray=\"2 4\" vector-effect=\"non-scaling-stroke\"/>"
    }

    return """
    <div class="share">
      <svg viewBox="0 0 1000 300" preserveAspectRatio="none">\(bands)\(rules)</svg>
      <i class="cursor" style="left:0%; display:none"></i>
      <span class="gridlabel" style="bottom:75%">75%</span>
      <span class="gridlabel" style="bottom:50%">50%</span>
      <span class="gridlabel" style="bottom:25%">25%</span>
    </div>
    <div class="axis"><span>\(liveWeeks.first?.start ?? "")</span><span>\(liveWeeks.last?.start ?? "")</span></div>
    """
}

func shareReadout() -> String {
    guard cursorWeek >= 0, cursorWeek < liveWeeks.count else {
        return "\(dayNames[band].uppercased()) · <b>\(percent(averageShare(day: band)))%</b> of a week on average"
    }
    return "week \(liveWeeks[cursorWeek].start) · <b>\(percent(shareOf(week: cursorWeek, day: band)))%</b> of the week"
}

// MARK: - The rail

/// A fraction as a CSS number. `percent` is for the readout and rounds to a
/// tenth, which is too coarse for a thumb travelling a long column.
func fraction(_ value: Double) -> String {
    let n = Int((min(max(value, 0), 1) * 1000).rounded())
    if n >= 1000 { return "1" }
    var digits = String(n)
    while digits.count < 3 { digits = "0" + digits }
    return "0." + digits
}

// MARK: - Wiring

func repaintShare() {
    document.querySelector!(".chartplot").object!.innerHTML = JSValue.string(shareChartHTML())
    document.querySelector!(".shareout").object!.innerHTML = JSValue.string(shareReadout())
    document.querySelector!(".bandnum").object!.textContent = JSValue.string("\(band + 1)")
    placeCursor()
}

func placeCursor() {
    let cursor = document.querySelector!(".share .cursor").object!
    let n = liveWeeks.count
    guard cursorWeek >= 0, n > 1 else {
        _ = cursor.setAttribute!("style", "display:none")
        return
    }
    let left = Double(cursorWeek) / Double(n - 1) * 100
    _ = cursor.setAttribute!("style", "left:\(percent(left / 100))%")
}

let app = document.getElementById!("app").object!
app.innerHTML = JSValue.string(boardHTML())

// the day pager: which weekday the accent follows
for step in [-1, 1] {
    let node = document.querySelector!(".cell.graphs .arrow[data-band=\"\(step)\"]").object!
    let handler = JSClosure { _ in
        band = (band + step + 7) % 7
        repaintShare()
        return .undefined
    }
    listeners.append(handler)
    // Click only. A pager that fires on hover changes the chart whenever the
    // pointer crosses it on the way somewhere else.
    _ = node.addEventListener!("click", JSValue.object(handler))
}

// the cursor follows the pointer across the weeks
let plot = document.querySelector!(".chartplot").object!
let move = JSClosure { args in
    guard let event = args.first?.object else { return .undefined }
    let box = plot.getBoundingClientRect!().object!
    let width = box.width.number ?? 1
    let x = (event.clientX.number ?? 0) - (box.left.number ?? 0)
    let n = liveWeeks.count
    let index = Int(((x / max(width, 1)) * Double(n - 1)).rounded())
    cursorWeek = min(max(index, 0), n - 1)
    document.querySelector!(".shareout").object!.innerHTML = JSValue.string(shareReadout())
    placeCursor()
    return .undefined
}
listeners.append(move)
_ = plot.addEventListener!("pointermove", JSValue.object(move))

let leave = JSClosure { _ in
    cursorWeek = -1
    document.querySelector!(".shareout").object!.innerHTML = JSValue.string(shareReadout())
    placeCursor()
    return .undefined
}
listeners.append(leave)
_ = plot.addEventListener!("pointerleave", JSValue.object(leave))

// The rail reads a list's scroll and can also drive it: a press anywhere on it
// jumps there, and the same gesture carries on as a drag.
func attachRail(list listSelector: String, rail railSelector: String) {
    guard let list = document.querySelector!(listSelector).object,
          let rail = document.querySelector!(railSelector).object else { return }
    let thumb = 8.0

    func sync() {
        let run = (list.scrollHeight.number ?? 0) - (list.clientHeight.number ?? 0)
        let at = run > 0 ? (list.scrollTop.number ?? 0) / run : 0
        _ = rail.style.object!.setProperty!("--p", fraction(at))
    }

    func goTo(_ event: JSObject) {
        let box = rail.getBoundingClientRect!().object!
        let run = max((box.height.number ?? 0) - thumb, 1)
        let at = ((event.clientY.number ?? 0) - (box.top.number ?? 0) - thumb / 2) / run
        let scrollable = (list.scrollHeight.number ?? 0) - (list.clientHeight.number ?? 0)
        list.scrollTop = JSValue.number(min(max(at, 0), 1) * scrollable)
    }

    let onScroll = JSClosure { _ in
        sync()
        return .undefined
    }
    listeners.append(onScroll)
    _ = list.addEventListener!("scroll", JSValue.object(onScroll))

    let down = JSClosure { args in
        guard let event = args.first?.object else { return .undefined }
        // capture lets the drag leave the ten pixels the rail is wide and carry on
        _ = rail.setPointerCapture!(event.pointerId)
        _ = event.preventDefault!()
        goTo(event)
        return .undefined
    }
    listeners.append(down)
    _ = rail.addEventListener!("pointerdown", JSValue.object(down))

    let move = JSClosure { args in
        guard let event = args.first?.object,
              rail.hasPointerCapture!(event.pointerId).boolean == true else { return .undefined }
        goTo(event)
        return .undefined
    }
    listeners.append(move)
    _ = rail.addEventListener!("pointermove", JSValue.object(move))

    sync()
}

attachRail(list: ".cell.chart .bars", rail: ".cell.chart .rail")
attachRail(list: ".cell.say .wall", rail: ".cell.say .rail")
