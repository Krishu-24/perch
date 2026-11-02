//
//  Parsers.swift
//  PerchDevCore
//
//  Turns the output of git, lsof and gh into DevSnapshot values.
//

import Foundation

public enum GitStatusParser {
    public struct Status: Equatable {
        public var branch: String
        public var ahead: Int
        public var behind: Int
        public var changed: Int
        public var untracked: Int
    }

    /// Parses `git status --porcelain=v2 --branch`.
    public static func parse(_ output: String) -> Status {
        var status = Status(branch: "?", ahead: 0, behind: 0, changed: 0, untracked: 0)
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            if line.hasPrefix("# branch.head ") {
                let head = String(line.dropFirst("# branch.head ".count))
                status.branch = head == "(detached)" ? "detached" : head
            } else if line.hasPrefix("# branch.ab ") {
                for part in line.dropFirst("# branch.ab ".count).split(separator: " ") {
                    if part.hasPrefix("+") { status.ahead = Int(part.dropFirst()) ?? 0 }
                    if part.hasPrefix("-") { status.behind = Int(part.dropFirst()) ?? 0 }
                }
            } else if line.hasPrefix("1 ") || line.hasPrefix("2 ") || line.hasPrefix("u ") {
                status.changed += 1
            } else if line.hasPrefix("? ") {
                status.untracked += 1
            }
        }
        return status
    }

    /// `owner/repo` from an origin URL on github.com, in any of its forms.
    public static func githubRepo(fromRemote remote: String) -> String? {
        var url = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["https://github.com/", "http://github.com/", "git@github.com:", "ssh://git@github.com/", "git://github.com/"] {
            if url.hasPrefix(prefix) {
                url = String(url.dropFirst(prefix.count))
                if url.hasSuffix(".git") { url = String(url.dropLast(4)) }
                if url.hasSuffix("/") { url = String(url.dropLast()) }
                let parts = url.split(separator: "/")
                return parts.count == 2 ? "\(parts[0])/\(parts[1])" : nil
            }
        }
        return nil
    }
}

public enum ListeningPortsParser {
    public struct Listener: Equatable {
        public var pid: Int
        public var command: String
        public var port: Int
    }

    /// Parses `lsof -nP -iTCP -sTCP:LISTEN -Fpcn`: one listener per process and port,
    /// however many addresses it listens on.
    public static func parseListeners(_ output: String) -> [Listener] {
        var result: [Listener] = []
        var seen = Set<String>()
        var pid: Int?
        var command = ""
        for line in output.split(separator: "\n") {
            guard let tag = line.first else { continue }
            let value = String(line.dropFirst())
            switch tag {
            case "p":
                pid = Int(value)
                command = ""
            case "c":
                command = value
            case "n":
                guard let pid, let colon = value.lastIndex(of: ":"), let port = Int(value[value.index(after: colon)...]) else { continue }
                if seen.insert("\(pid):\(port)").inserted {
                    result.append(Listener(pid: pid, command: command, port: port))
                }
            default:
                continue
            }
        }
        return result.sorted { $0.port < $1.port }
    }

    /// Parses `lsof -a -d cwd -p <pids> -Fpn` into each process's working directory.
    public static func parseWorkingDirectories(_ output: String) -> [Int: String] {
        var result: [Int: String] = [:]
        var pid: Int?
        for line in output.split(separator: "\n") {
            if line.hasPrefix("p") {
                pid = Int(line.dropFirst())
            } else if line.hasPrefix("n"), let pid {
                result[pid] = String(line.dropFirst())
            }
        }
        return result
    }

    /// Ports from here up are the system's temporary range (IANA "dynamic" ports). Tools such as
    /// Claude Code and editors listen there for their own use; dev servers pick fixed, lower ports.
    public static let firstDynamicPort = 49152

    /// A dev server is something you started from a project: its folder is inside your
    /// home folder but not the home folder itself or ~/Library. System services and apps
    /// run from "/" or their bundle, so they drop out.
    public static func devServers(listeners: [Listener], directories: [Int: String], home: String) -> [DevServer] {
        let home = home.hasSuffix("/") ? String(home.dropLast()) : home
        return listeners.compactMap { listener in
            guard listener.port < firstDynamicPort,
                  let directory = directories[listener.pid],
                  directory.hasPrefix(home + "/"),
                  !directory.hasPrefix(home + "/Library/") else { return nil }
            return DevServer(port: listener.port, command: listener.command, pid: listener.pid, directory: directory)
        }
    }
}

public enum CodexUsageParser {
    /// The newest rate-limit reading in the text of a Codex session file (`rollout-*.jsonl`),
    /// which records one with every reply: `primary` is the five-hour window, `secondary` the week.
    public static func latest(in text: String) -> CodexLimits? {
        for line in text.split(separator: "\n").reversed() where line.contains("\"rate_limits\"") {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  object["type"] as? String == "event_msg",
                  let payload = object["payload"] as? [String: Any],
                  payload["type"] as? String == "token_count",
                  let limits = payload["rate_limits"] as? [String: Any] else { continue }

            var fiveHour: UsageWindow?
            var week: UsageWindow?
            for key in ["primary", "secondary"] {
                guard let window = limits[key] as? [String: Any],
                      let used = (window["used_percent"] as? NSNumber)?.doubleValue else { continue }
                let resets = (window["resets_at"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
                let minutes = (window["window_minutes"] as? NSNumber)?.intValue ?? (key == "primary" ? 300 : 10080)
                let usage = UsageWindow(usedPercent: used, resetsAt: resets)
                if minutes <= 24 * 60 { fiveHour = usage } else { week = usage }
            }
            guard fiveHour != nil || week != nil else { continue }

            let stamp = (object["timestamp"] as? String).flatMap { iso.date(from: $0) ?? isoBasic.date(from: $0) }
            return CodexLimits(plan: limits["plan_type"] as? String, fiveHour: fiveHour, week: week,
                               capturedAt: stamp ?? Date())
        }
        return nil
    }

    private static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoBasic = ISO8601DateFormatter()
}

public enum ProcessSummary {
    /// Shortens a command line to what you'd recognise: the tool and its arguments, without
    /// paths or the interpreter. `node …/node_modules/.bin/next dev` → `next dev`.
    public static func summarize(_ arguments: String) -> String {
        let interpreters: Set<String> = ["node", "python", "python3", "ruby", "bun", "deno", "php", "java", "npx", "env"]
        var words = arguments.split(separator: " ").map(String.init)
        // Drop interpreters (python3.12 included) and their flags, such as `-m`.
        while let first = words.first {
            let name = URL(fileURLWithPath: first).lastPathComponent
            guard interpreters.contains(name)
                    || name.range(of: #"^python3\.\d+$"#, options: .regularExpression) != nil
                    || first.hasPrefix("-") else { break }
            words.removeFirst()
        }
        let shortened = words.prefix(3).map { word in
            word.contains("/") ? URL(fileURLWithPath: word).lastPathComponent : word
        }
        let summary = shortened.joined(separator: " ")
        return summary.isEmpty ? URL(fileURLWithPath: arguments.split(separator: " ").first.map(String.init) ?? "").lastPathComponent : summary
    }
}

public enum GitHubParser {
    /// The GraphQL query Perch Helper sends through `gh api graphql`.
    public static let viewerQuery = """
    query {
      viewer {
        login
        contributionsCollection {
          contributionCalendar {
            totalContributions
            weeks { contributionDays { date contributionCount } }
          }
        }
        pullRequests(first: 8, states: OPEN, orderBy: {field: UPDATED_AT, direction: DESC}) {
          nodes { ...pr }
        }
      }
      reviews: search(query: "is:open is:pr review-requested:@me archived:false", type: ISSUE, first: 5) {
        nodes { ... on PullRequest { ...pr } }
      }
    }
    fragment pr on PullRequest {
      number title url isDraft updatedAt reviewDecision
      repository { nameWithOwner }
      commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
    }
    """

    /// How many days of the contribution calendar to keep: a year, as GitHub shows it.
    public static let calendarDays = 371

    private struct Response: Decodable {
        struct Data: Decodable {
            let viewer: Viewer
            let reviews: Connection?
        }
        struct Viewer: Decodable {
            let login: String
            let contributionsCollection: Contributions
            let pullRequests: Connection
        }
        struct Contributions: Decodable {
            let contributionCalendar: Calendar
        }
        struct Calendar: Decodable {
            let totalContributions: Int
            let weeks: [Week]
        }
        struct Week: Decodable {
            let contributionDays: [Day]
        }
        struct Day: Decodable {
            let date: String
            let contributionCount: Int
        }
        struct Connection: Decodable {
            let nodes: [Node?]
        }
        struct Node: Decodable {
            let number: Int?
            let title: String?
            let url: String?
            let isDraft: Bool?
            let updatedAt: Date?
            let reviewDecision: String?
            let repository: Repository?
            let commits: Commits?
        }
        struct Repository: Decodable { let nameWithOwner: String }
        struct Commits: Decodable { let nodes: [CommitNode] }
        struct CommitNode: Decodable { let commit: Commit }
        struct Commit: Decodable { let statusCheckRollup: Rollup? }
        struct Rollup: Decodable { let state: String }

        let data: Data
    }

    /// Parses the answer to `viewerQuery`; `runs` come from separate `gh run list` calls.
    public static func parseViewer(_ json: Data, runs: [WorkflowRun] = []) throws -> GitHubSummary {
        let response = try DevSnapshot.decoder.decode(Response.self, from: json)
        let viewer = response.data.viewer
        let days = viewer.contributionsCollection.contributionCalendar.weeks
            .flatMap(\.contributionDays)
            .map { ContributionDay(date: $0.date, count: $0.contributionCount) }
        return GitHubSummary(
            login: viewer.login,
            totalContributions: viewer.contributionsCollection.contributionCalendar.totalContributions,
            days: Array(days.suffix(calendarDays)),
            pullRequests: viewer.pullRequests.nodes.compactMap(pullRequest),
            reviewRequests: (response.data.reviews?.nodes ?? []).compactMap(pullRequest),
            runs: runs
        )
    }

    private static func pullRequest(_ node: Response.Node?) -> PullRequest? {
        guard let node, let number = node.number, let title = node.title, let url = node.url,
              let repo = node.repository?.nameWithOwner, let updatedAt = node.updatedAt else { return nil }
        return PullRequest(
            repo: repo, number: number, title: title, url: url, isDraft: node.isDraft ?? false,
            checks: node.commits?.nodes.last?.commit.statusCheckRollup?.state,
            review: node.reviewDecision, updatedAt: updatedAt
        )
    }

    private struct Run: Decodable {
        let status: String
        let conclusion: String?
        let workflowName: String
        let headBranch: String
        let url: String
        let createdAt: Date
        let displayTitle: String
    }

    /// The JSON fields `gh run list` is asked for.
    public static let runFields = "status,conclusion,workflowName,headBranch,url,createdAt,displayTitle"

    /// Parses `gh run list --json <runFields>` for one repository.
    public static func parseRuns(_ json: Data, repo: String) throws -> [WorkflowRun] {
        try DevSnapshot.decoder.decode([Run].self, from: json).map {
            WorkflowRun(repo: repo, workflow: $0.workflowName, title: $0.displayTitle, branch: $0.headBranch,
                        status: $0.status, conclusion: $0.conclusion?.isEmpty == true ? nil : $0.conclusion,
                        url: $0.url, createdAt: $0.createdAt)
        }
    }
}
