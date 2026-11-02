//
//  DevSnapshot.swift
//  Perch
//
//  What Perch Helper writes to ~/Library/Application Support/Perch/dev.json
//  and the Dev tab reads. Shared by both: helper/Sources/PerchDevCore links here.
//

import Foundation

public struct DevSnapshot: Codable, Equatable {
    public var updatedAt: Date
    public var projects: [GitProject]
    public var servers: [DevServer]
    public var github: GitHubSummary?
    public var githubStatus: GitHubStatus
    /// Codex's plan limits, from its own session files; nil when Codex isn't used here.
    public var codex: CodexLimits?

    public init(updatedAt: Date, projects: [GitProject], servers: [DevServer], github: GitHubSummary?,
                githubStatus: GitHubStatus, codex: CodexLimits? = nil) {
        self.updatedAt = updatedAt
        self.projects = projects
        self.servers = servers
        self.github = github
        self.githubStatus = githubStatus
        self.codex = codex
    }

    public static let fileName = "dev.json"

    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

/// A local Git repository you've worked in with Claude recently.
public struct GitProject: Codable, Equatable, Identifiable {
    public var path: String
    public var branch: String
    public var ahead: Int
    public var behind: Int
    /// Staged or unstaged changes to tracked files.
    public var changed: Int
    public var untracked: Int
    public var lastCommit: String?
    public var lastCommitDate: Date?
    /// `owner/repo` when the origin remote is on GitHub.
    public var githubRepo: String?

    public var id: String { path }
    public var name: String { URL(fileURLWithPath: path).lastPathComponent }
    public var isClean: Bool { changed == 0 && untracked == 0 }

    public init(path: String, branch: String, ahead: Int = 0, behind: Int = 0, changed: Int = 0, untracked: Int = 0,
                lastCommit: String? = nil, lastCommitDate: Date? = nil, githubRepo: String? = nil) {
        self.path = path
        self.branch = branch
        self.ahead = ahead
        self.behind = behind
        self.changed = changed
        self.untracked = untracked
        self.lastCommit = lastCommit
        self.lastCommitDate = lastCommitDate
        self.githubRepo = githubRepo
    }
}

/// One plan window: how much is used, and when it starts over.
public struct UsageWindow: Codable, Equatable {
    public var usedPercent: Double
    public var resetsAt: Date?

    public init(usedPercent: Double, resetsAt: Date?) {
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
    }
}

/// Codex's five-hour and weekly windows as of its last reply.
public struct CodexLimits: Codable, Equatable {
    /// `plus`, `pro`, … as Codex reports it.
    public var plan: String?
    public var fiveHour: UsageWindow?
    public var week: UsageWindow?
    /// When Codex recorded these numbers.
    public var capturedAt: Date

    public init(plan: String?, fiveHour: UsageWindow?, week: UsageWindow?, capturedAt: Date) {
        self.plan = plan
        self.fiveHour = fiveHour
        self.week = week
        self.capturedAt = capturedAt
    }
}

/// A process listening on a local TCP port, started from a project folder.
public struct DevServer: Codable, Equatable, Identifiable {
    public var port: Int
    public var command: String
    public var pid: Int
    /// The folder the process runs in.
    public var directory: String
    /// What was run, shortened: "next dev", "vite", "uvicorn main:app".
    public var summary: String?

    public var id: Int { port }
    public var url: URL { URL(string: "http://localhost:\(port)")! }
    public var projectName: String { URL(fileURLWithPath: directory).lastPathComponent }

    public init(port: Int, command: String, pid: Int, directory: String, summary: String? = nil) {
        self.port = port
        self.command = command
        self.pid = pid
        self.directory = directory
        self.summary = summary
    }
}

public enum GitHubStatus: String, Codable, Equatable {
    case ok
    /// The `gh` command isn't installed.
    case notInstalled = "not_installed"
    /// `gh` is installed but not signed in.
    case signedOut = "signed_out"
    /// The last refresh failed; the data shown is the last good one, if any.
    case failed
}

public struct GitHubSummary: Codable, Equatable {
    public var login: String
    public var totalContributions: Int
    /// The last weeks of the contribution calendar, oldest first, one entry a day.
    public var days: [ContributionDay]
    public var pullRequests: [PullRequest]
    public var reviewRequests: [PullRequest]
    public var runs: [WorkflowRun]

    public init(login: String, totalContributions: Int, days: [ContributionDay], pullRequests: [PullRequest],
                reviewRequests: [PullRequest], runs: [WorkflowRun]) {
        self.login = login
        self.totalContributions = totalContributions
        self.days = days
        self.pullRequests = pullRequests
        self.reviewRequests = reviewRequests
        self.runs = runs
    }

    /// Days in a row, ending today or yesterday, with at least one contribution.
    public var currentStreak: Int {
        var streak = 0
        for (index, day) in days.reversed().enumerated() {
            if day.count > 0 {
                streak += 1
            } else if index == 0 {
                continue  // today may not have a contribution yet
            } else {
                break
            }
        }
        return streak
    }
}

public struct ContributionDay: Codable, Equatable {
    /// `yyyy-MM-dd`, as GitHub gives it.
    public var date: String
    public var count: Int

    public init(date: String, count: Int) {
        self.date = date
        self.count = count
    }
}

public struct PullRequest: Codable, Equatable, Identifiable {
    public var repo: String
    public var number: Int
    public var title: String
    public var url: String
    public var isDraft: Bool
    /// The combined check state: `SUCCESS`, `FAILURE`, `PENDING`, `ERROR`, `EXPECTED`, or nil with no checks.
    public var checks: String?
    /// `APPROVED`, `CHANGES_REQUESTED`, `REVIEW_REQUIRED`, or nil.
    public var review: String?
    public var updatedAt: Date

    public var id: String { "\(repo)#\(number)" }

    public init(repo: String, number: Int, title: String, url: String, isDraft: Bool, checks: String?, review: String?, updatedAt: Date) {
        self.repo = repo
        self.number = number
        self.title = title
        self.url = url
        self.isDraft = isDraft
        self.checks = checks
        self.review = review
        self.updatedAt = updatedAt
    }
}

public struct WorkflowRun: Codable, Equatable, Identifiable {
    public var repo: String
    public var workflow: String
    public var title: String
    public var branch: String
    /// `queued`, `in_progress`, `completed`, …
    public var status: String
    /// `success`, `failure`, `cancelled`, `skipped`, … once completed.
    public var conclusion: String?
    public var url: String
    public var createdAt: Date

    public var id: String { url }
    public var isRunning: Bool { status != "completed" }

    public init(repo: String, workflow: String, title: String, branch: String, status: String, conclusion: String?, url: String, createdAt: Date) {
        self.repo = repo
        self.workflow = workflow
        self.title = title
        self.branch = branch
        self.status = status
        self.conclusion = conclusion
        self.url = url
        self.createdAt = createdAt
    }
}

/// Where the widget board sits on the desktop.
public enum WidgetPosition: String, Codable, CaseIterable {
    case topRight, topLeft, bottomRight, bottomLeft
}

/// `settings.json` in Perch's folder. Perch writes it; Perch Helper reads it.
public struct WidgetSettings: Codable, Equatable {
    public var showDesktopWidgets: Bool
    public var position: WidgetPosition

    public init(showDesktopWidgets: Bool = true, position: WidgetPosition = .topRight) {
        self.showDesktopWidgets = showDesktopWidgets
        self.position = position
    }

    public static let fileName = "settings.json"

    public static func load(from folder: URL) -> WidgetSettings {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent(fileName)),
              let settings = try? JSONDecoder().decode(WidgetSettings.self, from: data) else { return WidgetSettings() }
        return settings
    }
}
