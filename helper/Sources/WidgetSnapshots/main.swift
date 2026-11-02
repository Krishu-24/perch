// Renders the desktop widget board with sample data to a PNG, over a dark wallpaper,
// so the widgets can be checked without putting them on the desktop.
// Usage: swift run WidgetSnapshots [output folder]

import AppKit
import PerchDevCore
import PerchWidgets
import SwiftUI

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "widget-snapshots", isDirectory: true)
let now = Date()

func day(_ offset: Int) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter.string(from: now.addingTimeInterval(Double(offset) * 86400))
}

let github = GitHubSummary(
    login: "Krishu-24", totalContributions: 1284,
    days: (0..<371).map { i in ContributionDay(date: day(i - 370), count: [0, 2, 5, 0, 1, 8, 3, 0, 4, 11, 6, 1, 0, 7][(i * 5 + i / 7) % 14]) },
    pullRequests: [
        PullRequest(repo: "Krishu-24/perch", number: 145, title: "Stream the activity feed", url: "https://github.com", isDraft: false,
                    checks: "PENDING", review: nil, updatedAt: now.addingTimeInterval(-7 * 60)),
        PullRequest(repo: "Krishu-24/site", number: 9, title: "Dark mode for the blog", url: "https://github.com", isDraft: false,
                    checks: "SUCCESS", review: "APPROVED", updatedAt: now.addingTimeInterval(-3 * 3600)),
    ],
    reviewRequests: [
        PullRequest(repo: "friend/notes-app", number: 142, title: "Glass cards for the dashboard", url: "https://github.com", isDraft: false,
                    checks: "SUCCESS", review: "REVIEW_REQUIRED", updatedAt: now.addingTimeInterval(-12 * 60)),
        PullRequest(repo: "friend/pocket-api", number: 88, title: "Retry uploads when the network drops", url: "https://github.com",
                    isDraft: false, checks: "FAILURE", review: "REVIEW_REQUIRED", updatedAt: now.addingTimeInterval(-3600)),
    ],
    runs: [
        WorkflowRun(repo: "Krishu-24/perch", workflow: "CI", title: "Dev tab", branch: "main", status: "in_progress",
                    conclusion: nil, url: "https://github.com", createdAt: now.addingTimeInterval(-114)),
        WorkflowRun(repo: "Krishu-24/site", workflow: "Deploy preview", title: "Login", branch: "fix/login-redirect", status: "completed",
                    conclusion: "success", url: "https://github.com", createdAt: now.addingTimeInterval(-6 * 60)),
        WorkflowRun(repo: "Krishu-24/api", workflow: "Tests", title: "Rate limits", branch: "feature/rate-limits", status: "completed",
                    conclusion: "failure", url: "https://github.com", createdAt: now.addingTimeInterval(-18 * 60)),
        WorkflowRun(repo: "Krishu-24/perch", workflow: "CI", title: "Limits", branch: "main", status: "completed",
                    conclusion: "success", url: "https://github.com", createdAt: now.addingTimeInterval(-3 * 3600)),
    ])

let snapshot = DevSnapshot(
    updatedAt: now,
    projects: [
        GitProject(path: "/Users/me/Code/perch", branch: "feature/glass-cards", ahead: 2, changed: 3, githubRepo: "Krishu-24/perch"),
        GitProject(path: "/Users/me/Code/pocket-api", branch: "main", behind: 1),
        GitProject(path: "/Users/me/Code/orbit-docs", branch: "main"),
        GitProject(path: "/Users/me/Code/site", branch: "main", untracked: 2),
    ],
    servers: [
        DevServer(port: 3000, command: "node", pid: 1, directory: "/Users/me/Code/site", summary: "next dev"),
        DevServer(port: 5173, command: "node", pid: 2, directory: "/Users/me/Code/orbit-docs", summary: "vite"),
        DevServer(port: 8080, command: "python3", pid: 3, directory: "/Users/me/Code/pocket-api", summary: "uvicorn main:app"),
    ],
    github: github, githubStatus: .ok,
    codex: CodexLimits(plan: "plus", fiveHour: UsageWindow(usedPercent: 12, resetsAt: now.addingTimeInterval(3 * 3600)),
                       week: UsageWindow(usedPercent: 30, resetsAt: now.addingTimeInterval(4 * 86400)), capturedAt: now))

@MainActor
func render(_ name: String, _ model: WidgetModel) throws {
    let view = WidgetBoard(model: model)
        .padding(40)
        .background(LinearGradient(colors: [Color(red: 0.12, green: 0.14, blue: 0.2), Color(red: 0.05, green: 0.06, blue: 0.09)],
                                   startPoint: .top, endPoint: .bottom))
    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
          let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "render", code: 1)
    }
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let url = output.appendingPathComponent("\(name).png")
    try png.write(to: url)
    print("wrote \(url.path)")
}

_ = NSApplication.shared
MainActor.assumeIsolated {
    let full = WidgetModel()
    full.snapshot = snapshot
    full.claude = ClaudeStatus(fiveHour: UsageWindow(usedPercent: 34, resetsAt: now.addingTimeInterval(80 * 60)),
                               week: UsageWindow(usedPercent: 22, resetsAt: now.addingTimeInterval(3 * 86400)),
                               updatedAt: now, working: 1, needsYou: 0)

    let empty = WidgetModel()
    empty.snapshot = DevSnapshot(updatedAt: now, projects: [], servers: [], github: nil, githubStatus: .signedOut)

    do {
        try render("widgets", full)
        try render("widgets-empty", empty)
    } catch {
        print(error)
        exit(1)
    }
}
