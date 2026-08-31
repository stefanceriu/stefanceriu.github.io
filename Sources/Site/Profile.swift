// The page's content. Everything the board renders is read from here.

struct Repo {
    /// owner/name, so repositories from the organisations sit in the same list.
    let full: String
    let blurb: String
    let stars: Int
    let forks: Int
    let language: String
    /// Merged pull requests authored here; zero for the repositories owned outright.
    let prs: Int

    var name: String { String(full.split(separator: "/").last ?? "") }
    var owner: String { String(full.split(separator: "/").first ?? "") }
    var owned: Bool { owner == Profile.handle }
    /// Straight to this account's work in the repository. Owned repositories are
    /// pushed to directly, so a pull request filter lands on an empty page there.
    var contributions: String {
        owned
            ? "https://github.com/\(full)/commits?author=\(Profile.handle)"
            : "https://github.com/\(full)/pulls?q=is%3Apr+author%3A\(Profile.handle)"
    }
}

struct Role {
    // Titles are only set where the export states one; the rest show the
    // organisation alone rather than a guessed job title.
    let title: String?
    let org: String
    let when: String?
}

enum Profile {
    static let firstName = "Stefan"
    static let lastName = "Ceriu"
    static let handle = "stefanceriu"
    static let headline = "iOS & Rust Engineer · Tech Lead at Element"
    static let colophon = "Made with love in Swift"
    static let bio = "Building open-source tools for a private, decentralised internet."

    static let stats: [(value: String, label: String)] = [
        ("4,603", "GitHub stars"),
        ("1,359", "merged PRs"),
        ("21", "public repos"),
        ("17+", "years shipping"),
    ]

    // Verbatim from the LinkedIn About section.
    static let lede = [
        "I’m an iOS and Rust engineer with 17+ years of experience, currently serving as Apple Platforms Tech Lead at Element, where I lead development of Element X, the open-source Matrix client for iOS and iPadOS, built for secure, decentralised communication.",
        "My work spans the full depth of the stack: Swift and SwiftUI on the client, Rust in the Matrix Rust SDK, and everything in between: architecture, protocol integration, performance, and cross-platform consistency. Before Swift, I spent years in Objective-C and UIKit, and my career started in C# on the Windows side, so I’m comfortable across the stack and across paradigms.",
        "I’ve spent my career building products that actually ship and get used, from pharmaceutical training platforms serving GSK, Novartis, and AstraZeneca, to thermal imaging apps at FLIR Systems, to nearly 8 years building EF’s global school platform, to open-source infrastructure used by teams worldwide.",
    ]

    // From the LinkedIn experience section, most recent first.
    static let roles = [
        Role(title: "Apple Platforms Tech Lead", org: "Element", when: "May 2021 — present"),
        Role(title: "iOS Developer", org: "FLIR Systems", when: "May 2020 — May 2021"),
        Role(title: "Senior Software Engineer", org: "EF Education First", when: "Oct 2012 — May 2020"),
        Role(title: "Software Engineer iOS", org: "Pentalog", when: "Aug 2010 — Oct 2012"),
        Role(title: "iOS Developer", org: "Freelance", when: "Oct 2009 — Aug 2010"),
        Role(title: "C#.Net Developer", org: "Code4Business", when: "Jul 2009 — Oct 2009"),
        Role(title: "iOS Developer", org: "Venture Corp", when: "Oct 2008 — Jul 2009"),
    ]

    static let links: [(label: String, url: String)] = [
        ("GitHub", "https://github.com/stefanceriu"),
        ("LinkedIn", "https://www.linkedin.com/in/stefanceriu/"),
    ]
}
