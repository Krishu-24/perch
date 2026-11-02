import XCTest
@testable import PerchDevCore

final class GitStatusParserTests: XCTestCase {
    func testBranchAheadBehindAndChanges() {
        let output = """
        # branch.oid 9344d1b0c0ffee
        # branch.head main
        # branch.upstream origin/main
        # branch.ab +2 -1
        1 .M N... 100644 100644 100644 aaa bbb README.md
        1 M. N... 100644 100644 100644 aaa bbb Sources/App.swift
        2 R. N... 100644 100644 100644 aaa bbb R100 New.swift\tOld.swift
        u UU N... 100644 100644 100644 100644 aaa bbb ccc Merge.swift
        ? notes.txt
        ? scratch/
        ! build/
        """
        XCTAssertEqual(GitStatusParser.parse(output),
                       .init(branch: "main", ahead: 2, behind: 1, changed: 4, untracked: 2))
    }

    func testCleanDetachedHeadWithoutUpstream() {
        let output = "# branch.oid abc\n# branch.head (detached)\n"
        XCTAssertEqual(GitStatusParser.parse(output),
                       .init(branch: "detached", ahead: 0, behind: 0, changed: 0, untracked: 0))
    }

    func testGitHubRemoteForms() {
        XCTAssertEqual(GitStatusParser.githubRepo(fromRemote: "https://github.com/Krishu-24/perch.git\n"), "Krishu-24/perch")
        XCTAssertEqual(GitStatusParser.githubRepo(fromRemote: "https://github.com/Krishu-24/perch"), "Krishu-24/perch")
        XCTAssertEqual(GitStatusParser.githubRepo(fromRemote: "git@github.com:Krishu-24/perch.git"), "Krishu-24/perch")
        XCTAssertEqual(GitStatusParser.githubRepo(fromRemote: "ssh://git@github.com/Krishu-24/perch.git"), "Krishu-24/perch")
        XCTAssertNil(GitStatusParser.githubRepo(fromRemote: "https://gitlab.com/someone/project.git"))
        XCTAssertNil(GitStatusParser.githubRepo(fromRemote: "https://github.com/Krishu-24"))
    }
}

final class ListeningPortsParserTests: XCTestCase {
    // As `lsof -nP -iTCP -sTCP:LISTEN -Fpcn` prints it: a process can listen on IPv4 and IPv6.
    let lsof = """
    p412
    cControlCe
    n*:7000
    n*:5000
    p9001
    cnode
    n127.0.0.1:5173
    n[::1]:5173
    p9002
    cpython3.12
    n*:8000
    p9003
    cpostgres
    n127.0.0.1:5432
    p9004
    cclaude
    n127.0.0.1:51027
    """

    func testListenersAreOnePerProcessAndPort() {
        let listeners = ListeningPortsParser.parseListeners(lsof)
        XCTAssertEqual(listeners.map(\.port), [5000, 5173, 5432, 7000, 8000, 51027])
        XCTAssertEqual(listeners.first { $0.port == 5173 }, .init(pid: 9001, command: "node", port: 5173))
    }

    func testOnlyProcessesStartedFromAProjectAreDevServers() {
        let cwd = """
        p412
        fcwd
        n/
        p9001
        fcwd
        n/Users/me/Code/website
        p9002
        fcwd
        n/Users/me/Code/api
        p9003
        fcwd
        n/Users/me/Library/Application Support/Postgres
        p9004
        fcwd
        n/Users/me/Code/website
        """
        let servers = ListeningPortsParser.devServers(
            listeners: ListeningPortsParser.parseListeners(lsof),
            directories: ListeningPortsParser.parseWorkingDirectories(cwd),
            home: "/Users/me/")
        XCTAssertEqual(servers, [
            DevServer(port: 5173, command: "node", pid: 9001, directory: "/Users/me/Code/website"),
            DevServer(port: 8000, command: "python3.12", pid: 9002, directory: "/Users/me/Code/api"),
        ])
        // Claude Code's own port, in the same project folder, is in the dynamic range and left out.
        XCTAssertEqual(servers.first?.url.absoluteString, "http://localhost:5173")
        XCTAssertEqual(servers.first?.projectName, "website")
    }
}

final class GitHubParserTests: XCTestCase {
    func testViewerContributionsPullRequestsAndReviews() throws {
        // 20 weeks of 7 days: day n has n % 4 contributions.
        let weeks = (0..<20).map { week in
            let days = (0..<7).map { day -> String in
                let n = week * 7 + day
                return #"{"date":"2026-\#(String(format: "%02d", 6 + n / 28))-\#(String(format: "%02d", 1 + n % 28))","contributionCount":\#(n % 4)}"#
            }
            return #"{"contributionDays":[\#(days.joined(separator: ","))]}"#
        }
        let json = """
        {"data":{
          "viewer":{
            "login":"Krishu-24",
            "contributionsCollection":{"contributionCalendar":{"totalContributions":321,"weeks":[\(weeks.joined(separator: ","))]}},
            "pullRequests":{"nodes":[
              {"number":12,"title":"Add the Dev tab","url":"https://github.com/Krishu-24/perch/pull/12","isDraft":false,
               "updatedAt":"2026-11-02T10:00:00Z","reviewDecision":"REVIEW_REQUIRED",
               "repository":{"nameWithOwner":"Krishu-24/perch"},
               "commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"SUCCESS"}}}]}},
              {"number":3,"title":"WIP","url":"https://github.com/Krishu-24/site/pull/3","isDraft":true,
               "updatedAt":"2026-11-01T10:00:00Z","reviewDecision":null,
               "repository":{"nameWithOwner":"Krishu-24/site"},
               "commits":{"nodes":[{"commit":{"statusCheckRollup":null}}]}}
            ]}
          },
          "reviews":{"nodes":[
            {"number":88,"title":"Fix login","url":"https://github.com/friend/app/pull/88","isDraft":false,
             "updatedAt":"2026-11-02T09:00:00Z","reviewDecision":"REVIEW_REQUIRED",
             "repository":{"nameWithOwner":"friend/app"},
             "commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"FAILURE"}}}]}},
            {}
          ]}
        }}
        """
        let summary = try GitHubParser.parseViewer(Data(json.utf8))
        XCTAssertEqual(summary.login, "Krishu-24")
        XCTAssertEqual(summary.totalContributions, 321)
        XCTAssertEqual(summary.days.count, GitHubParser.calendarDays, "keeps the last 17 weeks")
        XCTAssertEqual(summary.days.last?.count, 139 % 4)
        XCTAssertEqual(summary.pullRequests.map(\.id), ["Krishu-24/perch#12", "Krishu-24/site#3"])
        XCTAssertEqual(summary.pullRequests[0].checks, "SUCCESS")
        XCTAssertEqual(summary.pullRequests[1].checks, nil)
        XCTAssertTrue(summary.pullRequests[1].isDraft)
        XCTAssertEqual(summary.reviewRequests.map(\.id), ["friend/app#88"], "a node that isn't a pull request is skipped")
        XCTAssertEqual(summary.reviewRequests[0].checks, "FAILURE")
    }

    func testRuns() throws {
        let json = """
        [{"status":"completed","conclusion":"failure","workflowName":"CI","headBranch":"main",
          "url":"https://github.com/Krishu-24/perch/actions/runs/1","createdAt":"2026-11-02T10:00:00Z","displayTitle":"Add the Dev tab"},
         {"status":"in_progress","conclusion":"","workflowName":"Release","headBranch":"main",
          "url":"https://github.com/Krishu-24/perch/actions/runs/2","createdAt":"2026-11-02T11:00:00Z","displayTitle":"v1.1.0"}]
        """
        let runs = try GitHubParser.parseRuns(Data(json.utf8), repo: "Krishu-24/perch")
        XCTAssertEqual(runs.map(\.workflow), ["CI", "Release"])
        XCTAssertEqual(runs[0].conclusion, "failure")
        XCTAssertNil(runs[1].conclusion, "an empty conclusion means not finished")
        XCTAssertTrue(runs[1].isRunning)
        XCTAssertFalse(runs[0].isRunning)
    }

    func testStreakIgnoresAnEmptyToday() {
        func summary(_ counts: [Int]) -> GitHubSummary {
            GitHubSummary(login: "me", totalContributions: 0,
                          days: counts.enumerated().map { ContributionDay(date: "d\($0.offset)", count: $0.element) },
                          pullRequests: [], reviewRequests: [], runs: [])
        }
        XCTAssertEqual(summary([1, 0, 2, 3, 1]).currentStreak, 3)
        XCTAssertEqual(summary([1, 0, 2, 3, 0]).currentStreak, 2, "today without a contribution doesn't break it")
        XCTAssertEqual(summary([1, 2, 0, 0]).currentStreak, 0)
        XCTAssertEqual(summary([]).currentStreak, 0)
    }
}

final class DevSnapshotTests: XCTestCase {
    func testRoundTrip() throws {
        let snapshot = DevSnapshot(
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            projects: [GitProject(path: "/Users/me/Code/perch", branch: "main", ahead: 1, changed: 3,
                                  lastCommit: "Add the Dev tab", lastCommitDate: Date(timeIntervalSince1970: 1_799_999_000),
                                  githubRepo: "Krishu-24/perch")],
            servers: [DevServer(port: 5173, command: "node", pid: 1, directory: "/Users/me/Code/site")],
            github: nil, githubStatus: .signedOut)
        let data = try DevSnapshot.encoder.encode(snapshot)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains(#""githubStatus":"signed_out""#))
        XCTAssertEqual(try DevSnapshot.decoder.decode(DevSnapshot.self, from: data), snapshot)
        XCTAssertEqual(snapshot.projects[0].name, "perch")
        XCTAssertFalse(snapshot.projects[0].isClean)
    }
}
