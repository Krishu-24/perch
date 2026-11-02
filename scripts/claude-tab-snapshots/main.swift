// Renders the Claude tab to PNGs with sample data, so the layout can be checked
// without opening the notch. Run scripts/claude-tab-snapshots/render.sh.

import AppKit
import SwiftUI

let outputFolder = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "snapshots", isDirectory: true)

let now = Date()
func ago(_ seconds: Double) -> Double { (now.timeIntervalSince1970 - seconds) * 1000 }

let busySessions = [
    ClaudeSession(sessionId: "1", cwd: "/Users/me/Code/Mac_notch", surface: "desktop", status: .needsYou,
                  prompt: "Add the Claude tab", tool: "Bash", detail: "Waiting for your approval", updatedAt: ago(4)),
    ClaudeSession(sessionId: "2", cwd: "/Users/me/Downloads/General", surface: "desktop", status: .working,
                  prompt: "Summarize the research notes into a one-page brief", tool: "Read", detail: nil, updatedAt: ago(2)),
    ClaudeSession(sessionId: "3", cwd: "/Users/me/Code/website", surface: "terminal", status: .done,
                  prompt: "Fix the navbar on mobile", tool: nil, detail: nil, updatedAt: ago(95)),
    ClaudeSession(sessionId: "4", cwd: "/Users/me/Code/api", surface: "terminal", status: .working,
                  prompt: "Write tests for the billing module", tool: nil, detail: nil, updatedAt: ago(1)),
]

let calmUsage = ClaudeUsageSnapshot(
    fiveHour: ClaudeUsageWindow(usedPercentage: 18, resetsAt: now.addingTimeInterval(2 * 3600 + 14 * 60)),
    sevenDay: ClaudeUsageWindow(usedPercentage: 29, resetsAt: now.addingTimeInterval(4 * 86400 + 3 * 3600)),
    cachedAt: now.addingTimeInterval(-40)
)

let hotUsage = ClaudeUsageSnapshot(
    fiveHour: ClaudeUsageWindow(usedPercentage: 93, resetsAt: now.addingTimeInterval(38 * 60)),
    sevenDay: ClaudeUsageWindow(usedPercentage: 76, resetsAt: now.addingTimeInterval(86400 + 5 * 3600)),
    cachedAt: now.addingTimeInterval(-5)
)

/// The open notch at its real size (640 x 190): black, square top, rounded bottom,
/// a stand-in for the tab bar, and the tab's content inset the way ContentView insets it.
struct OpenNotchFrame<Content: View>: View {
    var tab = "Claude"
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // The tab bar as Perch draws it: icons only.
            HStack(spacing: 0) {
                ForEach([("Home", "house.fill"), ("Terminal", "apple.terminal.fill"), ("Limits", "gauge.with.dots.needle.33percent"),
                         ("Claude", "sparkles"), ("Dev", "chart.bar.xaxis")], id: \.0) { name, icon in
                    Image(systemName: icon)
                        .foregroundStyle(name == tab ? Color.white : Color.gray)
                        .padding(.horizontal, 15).frame(height: 26)
                        .background(Capsule().fill(Color.white.opacity(name == tab ? 0.12 : 0)))
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            content
        }
        .padding(.top, 8)
        .padding(.horizontal, 31)
        .padding(.bottom, 20)
        .frame(width: 640, height: 190, alignment: .topLeading)
        .background(UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24).fill(.black))
        .environment(\.colorScheme, .dark)
    }
}

/// The closed notch widened for a live activity: the physical notch in the middle, a square either side.
struct ClosedNotchFrame<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 10)
            .background(UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14).fill(.black))
            .environment(\.colorScheme, .dark)
    }
}

@MainActor
func render<V: View>(_ name: String, _ view: V) throws {
    let renderer = ImageRenderer(content: view.padding(20).background(Color(white: 0.85)))
    renderer.scale = 2
    guard let image = renderer.nsImage,
          let tiff = image.tiffRepresentation,
          let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "render", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not render \(name)"])
    }
    let url = outputFolder.appendingPathComponent("\(name).png")
    try png.write(to: url)
    print("wrote \(url.path)")
}

func day(_ offset: Int) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter.string(from: now.addingTimeInterval(Double(offset) * 86400))
}

let sampleGitHub = GitHubSummary(
    login: "Krishu-24", totalContributions: 412,
    days: (0..<119).map { i in ContributionDay(date: day(i - 118), count: [0, 1, 3, 0, 5, 8, 2, 0, 4, 12, 6, 1, 0, 7][(i * 7 + i / 5) % 14]) },
    pullRequests: [
        PullRequest(repo: "Krishu-24/perch", number: 14, title: "Add the Dev tab and drop-down terminal", url: "", isDraft: false,
                    checks: "SUCCESS", review: "APPROVED", updatedAt: now),
        PullRequest(repo: "Krishu-24/site", number: 7, title: "Dark mode for the blog", url: "", isDraft: true,
                    checks: "PENDING", review: nil, updatedAt: now),
    ],
    reviewRequests: [
        PullRequest(repo: "friend/notes-app", number: 88, title: "Fix sync on slow networks", url: "", isDraft: false,
                    checks: "FAILURE", review: "REVIEW_REQUIRED", updatedAt: now),
    ],
    runs: [
        WorkflowRun(repo: "Krishu-24/perch", workflow: "CI", title: "Dev tab", branch: "main", status: "in_progress",
                    conclusion: nil, url: "", createdAt: now.addingTimeInterval(-90)),
        WorkflowRun(repo: "Krishu-24/site", workflow: "Deploy", title: "Dark mode", branch: "dark-mode", status: "completed",
                    conclusion: "success", url: "", createdAt: now.addingTimeInterval(-25 * 60)),
        WorkflowRun(repo: "Krishu-24/perch", workflow: "Release", title: "v1.0.0", branch: "main", status: "completed",
                    conclusion: "failure", url: "", createdAt: now.addingTimeInterval(-3 * 3600)),
    ])

let sampleDev = DevSnapshot(
    updatedAt: now,
    projects: [
        GitProject(path: "/Users/me/Code/perch", branch: "main", ahead: 2, changed: 4, untracked: 1, githubRepo: "Krishu-24/perch"),
        GitProject(path: "/Users/me/Code/site", branch: "dark-mode", changed: 0, githubRepo: "Krishu-24/site"),
        GitProject(path: "/Users/me/Code/api", branch: "main", behind: 3, changed: 0),
    ],
    servers: [
        DevServer(port: 3000, command: "node", pid: 1, directory: "/Users/me/Code/site"),
        DevServer(port: 8000, command: "python3", pid: 2, directory: "/Users/me/Code/api"),
    ],
    github: sampleGitHub, githubStatus: .ok)

@MainActor
func renderAll() throws {
    try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
    let open: (ClaudeSession) -> Void = { _ in }
    try render("1-not-connected", OpenNotchFrame {
        ClaudeTabContent(sessions: [], usage: nil, isConnected: false, onOpen: open)
    })
    try render("2-no-sessions", OpenNotchFrame {
        ClaudeTabContent(sessions: [], usage: calmUsage, isConnected: true, onOpen: open, isScrollable: false)
    })
    try render("3-busy", OpenNotchFrame {
        ClaudeTabContent(sessions: busySessions, usage: calmUsage, isConnected: true, onOpen: open, isScrollable: false)
    })
    try render("5-closed-notch", VStack(spacing: 12) {
        ClosedNotchFrame { ClaudeLiveActivity(needsYouCount: 0, workingCount: 1, fiveHour: calmUsage.fiveHour, notchHeight: 32, notchWidth: 180) }
        ClosedNotchFrame { ClaudeLiveActivity(needsYouCount: 1, workingCount: 1, fiveHour: hotUsage.fiveHour, notchHeight: 32, notchWidth: 180) }
        ClosedNotchFrame { ClaudeLiveActivity(needsYouCount: 3, workingCount: 0, fiveHour: calmUsage.fiveHour, notchHeight: 32, notchWidth: 180) }
        ClosedNotchFrame { ClaudeLiveActivity(needsYouCount: 0, workingCount: 0, justFinishedCount: 1, fiveHour: calmUsage.fiveHour, notchHeight: 32, notchWidth: 180) }
    })
    try render("9-limits", OpenNotchFrame(tab: "Limits") {
        LimitsContent(
            claude: ClaudeUsageSnapshot(fiveHour: ClaudeUsageWindow(usedPercentage: 18, resetsAt: now.addingTimeInterval(80 * 60)),
                                        sevenDay: ClaudeUsageWindow(usedPercentage: 29, resetsAt: now.addingTimeInterval(4 * 86400)),
                                        cachedAt: now.addingTimeInterval(-120)),
            codex: CodexLimits(plan: "plus", fiveHour: UsageWindow(usedPercent: 9, resetsAt: now.addingTimeInterval(190 * 60)),
                               week: UsageWindow(usedPercent: 1, resetsAt: now.addingTimeInterval(5 * 86400)),
                               capturedAt: now.addingTimeInterval(-25 * 60)),
            isClaudeConnected: true)
    })
    try render("6-dev", OpenNotchFrame(tab: "Dev") {
        DevTabContent(snapshot: sampleDev, isHelperRunning: true, isHelperInstalled: true)
    })
    try render("7-dev-signed-out", OpenNotchFrame(tab: "Dev") {
        DevTabContent(snapshot: DevSnapshot(updatedAt: now, projects: sampleDev.projects, servers: [], github: nil, githubStatus: .signedOut),
                      isHelperRunning: true, isHelperInstalled: true)
    })
    try render("8-dev-no-helper", OpenNotchFrame(tab: "Dev") {
        DevTabContent(snapshot: nil, isHelperRunning: false, isHelperInstalled: true)
    })
    try render("4-near-limit", OpenNotchFrame {
        ClaudeTabContent(sessions: Array(busySessions.prefix(2)), usage: hotUsage, isConnected: true, onOpen: open, isScrollable: false)
    })
}

_ = NSApplication.shared
MainActor.assumeIsolated {
    do { try renderAll() } catch { print(error.localizedDescription); exit(1) }
}
