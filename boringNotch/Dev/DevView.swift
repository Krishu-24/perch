//
//  DevView.swift
//  Perch
//
//  The Dev tab, readable at a glance with nothing to scroll: the terminal on the
//  left, your contribution graph as the anchor, and four cards that each answer one
//  question (pull requests, Actions, dev servers, Git) in a word or two. A card that
//  needs you is outlined in amber or red, so the eye goes there first.
//

import SwiftUI

struct DevView: View {
    @ObservedObject var store = DevStore.shared

    var body: some View {
        DevTabContent(
            snapshot: store.snapshot,
            isHelperRunning: store.isHelperRunning,
            isHelperInstalled: DevStore.helperURL != nil,
            actions: DevActions(
                toggleTerminal: store.toggleTerminal,
                openTerminal: store.openTerminal(in:),
                open: store.open,
                startHelper: store.startHelper,
                refresh: store.refresh
            )
        )
        .onAppear {
            store.startHelper()
            // Just signed in to gh? Check now rather than at the next 3-minute refresh.
            if let status = store.snapshot?.githubStatus, status != .ok { store.refresh() }
        }
    }
}

struct DevActions {
    var toggleTerminal: () -> Void = {}
    var openTerminal: (GitProject) -> Void = { _ in }
    var open: (String) -> Void = { _ in }
    var startHelper: () -> Void = {}
    var refresh: () -> Void = {}
}

/// The tab drawn from plain values, so the snapshot script can render it.
struct DevTabContent: View {
    let snapshot: DevSnapshot?
    let isHelperRunning: Bool
    let isHelperInstalled: Bool
    var actions = DevActions()

    static let height: CGFloat = 128
    static let gap: CGFloat = 8

    var body: some View {
        if !isHelperInstalled {
            ClaudeEmptyState(title: "Perch Helper isn't installed",
                             detail: "The Dev tab and the terminal need Perch Helper. The README explains how to add it.")
        } else if let snapshot {
            HStack(spacing: Self.gap) {
                DevTerminalTile(action: actions.toggleTerminal)
                DevContributionsTile(github: snapshot.github, status: snapshot.githubStatus, actions: actions)
                VStack(spacing: Self.gap) {
                    HStack(spacing: Self.gap) {
                        DevPullRequestsTile(github: snapshot.github, status: snapshot.githubStatus, actions: actions)
                        DevActionsTile(github: snapshot.github, status: snapshot.githubStatus, actions: actions)
                    }
                    HStack(spacing: Self.gap) {
                        DevServersTile(servers: snapshot.servers, actions: actions)
                        DevGitTile(projects: snapshot.projects, actions: actions)
                    }
                }
            }
            .frame(height: Self.height)
            .padding(.top, 4)
        } else {
            VStack(spacing: 10) {
                ClaudeEmptyState(title: isHelperRunning ? "Collecting…" : "Perch Helper isn't running",
                                 detail: "It gathers your Git status, dev servers and GitHub activity.")
                    .frame(height: 50)
                if !isHelperRunning {
                    DevPillButton(title: "Start Perch Helper", action: actions.startHelper)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Building blocks

/// How a card looks: calm when there's nothing to do, outlined when it wants you.
enum DevTone {
    case quiet, good, busy, attention, problem

    var color: Color {
        switch self {
        case .quiet: Color.white.opacity(0.25)
        case .good: TerminalColors.green
        case .busy, .attention: TerminalColors.amber
        case .problem: TerminalColors.red
        }
    }

    var isOutlined: Bool { self == .attention || self == .problem }
}

/// One card: a small label on top, a headline that answers the card's question, and
/// one line of detail. The whole card is the button.
struct DevTile: View {
    let title: String
    let icon: String
    let headline: String
    var detail: String?
    var tone: DevTone = .quiet
    var hint: String?
    var action: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        Button { action?() } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .semibold))
                    Text(title)
                        .font(.system(size: 9.5, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(0.3)
                    Spacer(minLength: 2)
                    if tone != .quiet {
                        Circle().fill(tone.color).frame(width: 6, height: 6)
                    }
                }
                .foregroundColor(.white.opacity(0.42))
                Spacer(minLength: 0)
                Text(headline)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(tone == .quiet ? .white.opacity(0.55) : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(detail ?? " ")
                    .font(.system(size: 10.5))
                    .foregroundColor(.white.opacity(0.42))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(tone.isOutlined ? tone.color.opacity(isHovered ? 0.16 : 0.1) : Color.white.opacity(isHovered ? 0.1 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(tone.color.opacity(tone.isOutlined ? 0.45 : 0), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .onHover { isHovered = $0 && action != nil }
        .help(hint ?? "")
    }
}

struct DevPillButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.9)))
        }
        .buttonStyle(.plain)
    }
}

private func repoName(_ fullName: String) -> String {
    fullName.split(separator: "/").last.map(String.init) ?? fullName
}

// MARK: - Terminal

struct DevTerminalTile: View {
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(TerminalColors.prompt)
                Text("Terminal")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                HStack(spacing: 1) {
                    Image(systemName: "control")
                        .font(.system(size: 9, weight: .bold))
                    Text("`")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.white.opacity(0.2)))
            }
            .frame(width: 60)
            .frame(maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(isHovered ? 0.11 : 0.06)))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Drop the terminal out of the notch (Control-`)")
    }
}

// MARK: - Contributions

struct DevContributionsTile: View {
    let github: GitHubSummary?
    let status: GitHubStatus
    let actions: DevActions

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 9, weight: .semibold))
                Text("GitHub")
                    .font(.system(size: 9.5, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.3)
                Spacer(minLength: 2)
                if let github {
                    Text("\(github.totalContributions)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                    + Text(" this year")
                        .font(.system(size: 9.5, weight: .medium))
                }
            }
            .foregroundColor(.white.opacity(0.42))

            ContributionGraph(days: github?.days ?? [])
                .frame(width: ContributionGraph.width, height: ContributionGraph.height)
                .opacity(github == nil ? 0.5 : 1)

            Spacer(minLength: 0)
            footer
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: ContributionGraph.width + 20)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
    }

    @ViewBuilder
    private var footer: some View {
        if let github {
            let streak = github.currentStreak
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10))
                    .foregroundColor(streak > 0 ? TerminalColors.amber : .white.opacity(0.3))
                Text(streak > 0 ? "\(streak)-day streak" : "No streak yet")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(streak > 0 ? .white : .white.opacity(0.5))
            }
        } else {
            Button(action: actions.toggleTerminal) {
                Text(status == .notInstalled ? "Install gh to connect GitHub" : "Connect GitHub · gh auth login")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(TerminalColors.amber)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(.plain)
            .help("Open the terminal to sign in to the GitHub CLI")
        }
    }
}

/// GitHub's calendar: one column a week, Sunday at the top, greener for more contributions.
/// With no data it draws an empty grid, so the card keeps its shape.
struct ContributionGraph: View {
    let days: [ContributionDay]

    static let weeks = 17
    static let cell: CGFloat = 8
    static let gap: CGFloat = 2
    static let width = CGFloat(weeks) * (cell + gap) - gap
    static let height = 7 * (cell + gap) - gap

    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Rows before the first day, so each column is a Sunday-to-Saturday week.
    private var leadingBlanks: Int {
        guard let first = days.first, let date = Self.parser.date(from: first.date) else { return 0 }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.component(.weekday, from: date) - 1
    }

    static func color(for count: Int, max: Int) -> Color {
        guard count > 0, max > 0 else { return Color.white.opacity(0.08) }
        let share = Double(count) / Double(max)
        let opacity = share <= 0.25 ? 0.35 : share <= 0.5 ? 0.55 : share <= 0.75 ? 0.8 : 1.0
        return TerminalColors.green.opacity(opacity)
    }

    var body: some View {
        let maxCount = days.map(\.count).max() ?? 0
        let offset = leadingBlanks
        // Keep the newest weeks if the calendar runs longer than the card.
        let slots = days.count + offset
        let skip = max(0, (slots + 6) / 7 - Self.weeks) * 7
        Canvas { context, _ in
            let total = days.isEmpty ? Self.weeks * 7 : slots
            for slot in skip..<total {
                let index = slot - offset
                let count = (index >= 0 && index < days.count) ? days[index].count : 0
                if !days.isEmpty && index < 0 { continue }
                let column = (slot - skip) / 7
                let rect = CGRect(x: CGFloat(column) * (Self.cell + Self.gap),
                                  y: CGFloat(slot % 7) * (Self.cell + Self.gap),
                                  width: Self.cell, height: Self.cell)
                context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(Self.color(for: count, max: maxCount)))
            }
        }
    }
}

// MARK: - GitHub cards

struct DevPullRequestsTile: View {
    let github: GitHubSummary?
    let status: GitHubStatus
    let actions: DevActions

    static func checksTone(_ state: String?) -> DevTone {
        switch state {
        case "FAILURE", "ERROR": .problem
        case "PENDING", "EXPECTED": .busy
        case "SUCCESS": .good
        default: .quiet
        }
    }

    var body: some View {
        if let github {
            let reviews = github.reviewRequests
            let mine = github.pullRequests
            let failing = mine.first { Self.checksTone($0.checks) == .problem }
            if let review = reviews.first {
                DevTile(title: "Pull requests", icon: "arrow.triangle.pull",
                        headline: reviews.count == 1 ? "1 review waiting" : "\(reviews.count) reviews waiting",
                        detail: "\(review.title) · \(repoName(review.repo))", tone: .attention,
                        hint: "Open \(review.repo) #\(review.number)", action: { actions.open(review.url) })
            } else if let failing {
                DevTile(title: "Pull requests", icon: "arrow.triangle.pull", headline: "Checks failing",
                        detail: "\(failing.title) · #\(failing.number)", tone: .problem,
                        hint: "Open \(failing.repo) #\(failing.number)", action: { actions.open(failing.url) })
            } else if let top = mine.first {
                DevTile(title: "Pull requests", icon: "arrow.triangle.pull",
                        headline: mine.count == 1 ? "1 open" : "\(mine.count) open",
                        detail: top.title, tone: Self.checksTone(top.checks),
                        hint: "Open \(top.repo) #\(top.number)", action: { actions.open(top.url) })
            } else {
                DevTile(title: "Pull requests", icon: "arrow.triangle.pull", headline: "All clear",
                        detail: "Nothing open or waiting", action: { actions.open("https://github.com/pulls") })
            }
        } else {
            DevGitHubSetupTile(title: "Pull requests", icon: "arrow.triangle.pull", status: status, actions: actions)
        }
    }
}

struct DevActionsTile: View {
    let github: GitHubSummary?
    let status: GitHubStatus
    let actions: DevActions

    var body: some View {
        if let github {
            let runs = github.runs
            // A running or failed run is the news; otherwise the newest one.
            if let run = runs.first(where: \.isRunning) ?? runs.first(where: { Self.isFailure($0) }) ?? runs.first {
                let (headline, tone) = Self.summary(run)
                DevTile(title: "Actions", icon: "bolt.horizontal.fill", headline: headline,
                        detail: "\(repoName(run.repo)) · \(run.branch) · \(ClaudeFormatting.ageText(run.createdAt))",
                        tone: tone, hint: "Open the \(run.workflow) run", action: { actions.open(run.url) })
            } else {
                DevTile(title: "Actions", icon: "bolt.horizontal.fill", headline: "No recent runs",
                        detail: "In your projects")
            }
        } else {
            DevGitHubSetupTile(title: "Actions", icon: "bolt.horizontal.fill", status: status, actions: actions)
        }
    }

    static func isFailure(_ run: WorkflowRun) -> Bool {
        ["failure", "timed_out", "startup_failure"].contains(run.conclusion ?? "")
    }

    static func summary(_ run: WorkflowRun) -> (String, DevTone) {
        if run.isRunning { return ("\(run.workflow) running", .busy) }
        if isFailure(run) { return ("\(run.workflow) failed", .problem) }
        if run.conclusion == "success" { return ("\(run.workflow) passed", .good) }
        return ("\(run.workflow) \(run.conclusion ?? "finished")", .quiet)
    }
}

/// Stands in for a GitHub card until the GitHub CLI is installed and signed in.
struct DevGitHubSetupTile: View {
    let title: String
    let icon: String
    let status: GitHubStatus
    let actions: DevActions

    var body: some View {
        switch status {
        case .notInstalled:
            DevTile(title: title, icon: icon, headline: "Connect GitHub", detail: "brew install gh",
                    hint: "Open the terminal to install the GitHub CLI", action: actions.toggleTerminal)
        case .signedOut:
            DevTile(title: title, icon: icon, headline: "Connect GitHub", detail: "Run gh auth login",
                    hint: "Open the terminal to sign in", action: actions.toggleTerminal)
        case .failed, .ok:
            DevTile(title: title, icon: icon, headline: "GitHub unreachable", detail: "Click to try again",
                    action: actions.refresh)
        }
    }
}

// MARK: - Local cards

struct DevServersTile: View {
    let servers: [DevServer]
    let actions: DevActions

    var body: some View {
        if let first = servers.first {
            let more = servers.count > 1 ? " · +\(servers.count - 1) more" : ""
            DevTile(title: "Dev servers", icon: "server.rack", headline: "localhost:\(first.port)",
                    detail: "\(first.projectName) · \(first.command)\(more)", tone: .good,
                    hint: "Open \(first.url.absoluteString)", action: { actions.open(first.url.absoluteString) })
        } else {
            DevTile(title: "Dev servers", icon: "server.rack", headline: "None running",
                    detail: "Nothing listening yet")
        }
    }
}

struct DevGitTile: View {
    let projects: [GitProject]
    let actions: DevActions

    static func detail(_ project: GitProject) -> String {
        var parts: [String] = [project.branch]
        if project.changed > 0 { parts.append("\(project.changed) changed") }
        if project.untracked > 0 { parts.append("\(project.untracked) new") }
        if project.ahead > 0 { parts.append("↑\(project.ahead)") }
        if project.behind > 0 { parts.append("↓\(project.behind)") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        let dirty = projects.filter { !$0.isClean }
        if let top = dirty.first {
            let others = dirty.count > 1 ? "\(dirty.count) projects" : top.name
            DevTile(title: "Git", icon: "arrow.triangle.branch",
                    headline: "Changes in \(others)",
                    detail: Self.detail(top), tone: .attention,
                    hint: "Open the terminal in \(top.name)", action: { actions.openTerminal(top) })
        } else if let top = projects.first {
            let ahead = projects.first { $0.ahead > 0 }
            DevTile(title: "Git", icon: "arrow.triangle.branch",
                    headline: ahead.map { "\($0.name) ↑\($0.ahead) to push" } ?? "All committed",
                    detail: projects.count == 1 ? "\(top.name) · \(top.branch)" : "\(projects.count) projects",
                    tone: ahead == nil ? .good : .busy,
                    hint: "Open the terminal in \((ahead ?? top).name)", action: { actions.openTerminal(ahead ?? top) })
        } else {
            DevTile(title: "Git", icon: "arrow.triangle.branch", headline: "No projects yet",
                    detail: "Work with Claude in a repo")
        }
    }
}
