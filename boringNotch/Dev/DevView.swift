//
//  DevView.swift
//  Perch
//
//  The Dev tab: a row of cards for the terminal, your GitHub contributions, pull
//  requests, Actions runs, running dev servers and your projects' Git status.
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
    /// Off only for snapshots: ImageRenderer draws a ScrollView's content blank.
    var isScrollable = true

    static let cardHeight: CGFloat = 128

    var body: some View {
        if !isHelperInstalled {
            ClaudeEmptyState(title: "Perch Helper isn't installed",
                             detail: "The Dev tab and the terminal need Perch Helper. The README explains how to add it.")
        } else if snapshot == nil {
            VStack(spacing: 10) {
                ClaudeEmptyState(title: isHelperRunning ? "Collecting…" : "Perch Helper isn't running",
                                 detail: "It gathers your Git status, dev servers and GitHub activity.")
                    .frame(height: 50)
                if !isHelperRunning {
                    DevPillButton(title: "Start Perch Helper", action: actions.startHelper)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isScrollable {
            ScrollView(.horizontal, showsIndicators: false) { cards }
                .scrollBounceBehavior(.basedOnSize)
                .mask(Self.edgeFade)
        } else {
            cards.mask(Self.edgeFade)
        }
    }

    /// Fades the last few points on the right, a hint that more cards scroll in.
    static let edgeFade = LinearGradient(
        stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.93), .init(color: .clear, location: 1)],
        startPoint: .leading, endPoint: .trailing)

    private var cards: some View {
        HStack(alignment: .top, spacing: 8) {
            DevTerminalTile(action: actions.toggleTerminal)
            if let github = snapshot?.github {
                DevContributionsCard(github: github)
                DevPullRequestsCard(github: github, open: actions.open)
                DevActionsCard(runs: github.runs, open: actions.open)
            } else {
                DevGitHubSetupCard(status: snapshot?.githubStatus ?? .failed, actions: actions)
            }
            DevServersCard(servers: snapshot?.servers ?? [], open: actions.open)
            DevProjectsCard(projects: snapshot?.projects ?? [], open: actions.openTerminal)
        }
        .padding(.top, 4)
    }
}

// MARK: - Building blocks

struct DevCard<Content: View>: View {
    let title: String
    let icon: String
    let width: CGFloat
    var accessory: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.3)
                Spacer(minLength: 4)
                if let accessory {
                    Text(accessory)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
            }
            .foregroundColor(.white.opacity(0.45))
            content
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: width, height: DevTabContent.cardHeight, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
    }
}

/// One line in a card: a status mark, a title and a grey detail line; clickable.
struct DevRow<Leading: View>: View {
    let title: String
    var tag: String?
    let detail: String
    var titleDesign: Font.Design = .default
    var action: (() -> Void)?
    @ViewBuilder var leading: Leading

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            leading
                .frame(width: 12)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(title)
                        .font(.system(size: 11.5, weight: .medium, design: titleDesign))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .layoutPriority(1)
                    if let tag {
                        Text(tag)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                            .lineLimit(1)
                    }
                }
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(RoundedRectangle(cornerRadius: 6).fill(isHovered && action != nil ? Color.white.opacity(0.08) : .clear))
        .contentShape(Rectangle())
        .onTapGesture { action?() }
        .onHover { isHovered = $0 }
    }
}

struct DevNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10.5))
            .foregroundColor(.white.opacity(0.35))
            .fixedSize(horizontal: false, vertical: true)
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

struct DevDot: View {
    let color: Color

    var body: some View {
        Circle().fill(color).frame(width: 7, height: 7)
    }
}

// MARK: - Cards

struct DevTerminalTile: View {
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(TerminalColors.prompt)
                Text("Terminal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                Text("⌃ `")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.2)))
            }
            .frame(width: 72, height: DevTabContent.cardHeight)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(isHovered ? 0.11 : 0.06)))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Drop the terminal out of the notch (Control-`)")
    }
}

struct DevContributionsCard: View {
    let github: GitHubSummary

    var body: some View {
        DevCard(title: "Contributions", icon: "square.grid.3x3.fill", width: 178) {
            ContributionGraph(days: github.days)
                .frame(height: 61)
            Text("\(github.totalContributions) this year")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
            Text(github.currentStreak == 1 ? "1-day streak" : "\(github.currentStreak)-day streak")
                .font(.system(size: 10))
                .foregroundColor(github.currentStreak > 0 ? TerminalColors.green : .white.opacity(0.4))
        }
    }
}

/// GitHub's calendar: one column a week, Sunday at the top, greener for more contributions.
struct ContributionGraph: View {
    let days: [ContributionDay]

    private static let cell: CGFloat = 7
    private static let gap: CGFloat = 2

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
        Canvas { context, _ in
            for (index, day) in days.enumerated() {
                let slot = index + offset
                let rect = CGRect(x: CGFloat(slot / 7) * (Self.cell + Self.gap),
                                  y: CGFloat(slot % 7) * (Self.cell + Self.gap),
                                  width: Self.cell, height: Self.cell)
                context.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(Self.color(for: day.count, max: maxCount)))
            }
        }
    }
}

struct DevPullRequestsCard: View {
    let github: GitHubSummary
    let open: (String) -> Void

    /// Reviews waiting on you first, then your own, three at most.
    private var rows: [(pr: PullRequest, isReview: Bool)] {
        Array((github.reviewRequests.map { ($0, true) } + github.pullRequests.map { ($0, false) }).prefix(3))
    }

    static func checksColor(_ state: String?) -> Color {
        switch state {
        case "SUCCESS": TerminalColors.green
        case "FAILURE", "ERROR": TerminalColors.red
        case "PENDING", "EXPECTED": TerminalColors.amber
        default: Color.white.opacity(0.25)
        }
    }

    static func detail(_ pr: PullRequest, isReview: Bool) -> String {
        let name = pr.repo.split(separator: "/").last.map(String.init) ?? pr.repo
        let state: String
        if isReview { state = "Review requested" }
        else if pr.isDraft { state = "Draft" }
        else {
            switch pr.review {
            case "APPROVED": state = "Approved"
            case "CHANGES_REQUESTED": state = "Changes requested"
            default: state = "Awaiting review"
            }
        }
        return "\(name) #\(pr.number) · \(state)"
    }

    var body: some View {
        let total = github.pullRequests.count + github.reviewRequests.count
        DevCard(title: "Pull requests", icon: "arrow.triangle.pull", width: 226, accessory: total > 0 ? "\(total)" : nil) {
            if rows.isEmpty {
                DevNote(text: "No open pull requests. Nice and tidy.")
            }
            ForEach(rows, id: \.pr.id) { row in
                DevRow(title: row.pr.title, detail: Self.detail(row.pr, isReview: row.isReview), action: { open(row.pr.url) }) {
                    if row.isReview {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(TerminalColors.amber)
                    } else {
                        DevDot(color: Self.checksColor(row.pr.checks))
                    }
                }
            }
        }
    }
}

struct DevActionsCard: View {
    let runs: [WorkflowRun]
    let open: (String) -> Void

    @ViewBuilder
    static func mark(for run: WorkflowRun) -> some View {
        let (symbol, color): (String, Color) = {
            if run.isRunning { return ("clock.arrow.circlepath", TerminalColors.amber) }
            switch run.conclusion {
            case "success": return ("checkmark.circle.fill", TerminalColors.green)
            case "failure", "timed_out", "startup_failure": return ("xmark.circle.fill", TerminalColors.red)
            default: return ("minus.circle.fill", Color.white.opacity(0.35))
            }
        }()
        Image(systemName: symbol)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
    }

    var body: some View {
        DevCard(title: "Actions", icon: "bolt.horizontal.fill", width: 206,
                accessory: runs.contains(where: \.isRunning) ? "running" : nil) {
            if runs.isEmpty {
                DevNote(text: "No recent runs in your projects.")
            }
            ForEach(Array(runs.prefix(3).enumerated()), id: \.offset) { _, run in
                let repo = run.repo.split(separator: "/").last.map(String.init) ?? run.repo
                DevRow(title: run.workflow, detail: "\(repo) · \(run.branch) · \(ClaudeFormatting.ageText(run.createdAt))",
                       action: { open(run.url) }) {
                    Self.mark(for: run)
                }
            }
        }
    }
}

struct DevGitHubSetupCard: View {
    let status: GitHubStatus
    let actions: DevActions

    var body: some View {
        DevCard(title: "GitHub", icon: "arrow.triangle.pull", width: 226) {
            switch status {
            case .notInstalled:
                DevNote(text: "Install the GitHub CLI to see pull requests, Actions and contributions here.")
                Text("brew install gh")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .textSelection(.enabled)
            case .signedOut:
                DevNote(text: "Sign in once to see pull requests, Actions and contributions.")
                Text("gh auth login")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .textSelection(.enabled)
                DevPillButton(title: "Open Terminal", action: actions.toggleTerminal)
            case .failed, .ok:
                DevNote(text: "Couldn't reach GitHub. Perch tries again every few minutes.")
                DevPillButton(title: "Try Now", action: actions.refresh)
            }
        }
    }
}

struct DevServersCard: View {
    let servers: [DevServer]
    let open: (String) -> Void

    var body: some View {
        DevCard(title: "Dev servers", icon: "server.rack", width: 176, accessory: servers.isEmpty ? nil : "\(servers.count)") {
            if servers.isEmpty {
                DevNote(text: "Nothing running. Start a dev server and it shows up here.")
            }
            ForEach(servers.prefix(3)) { server in
                DevRow(title: ":\(server.port)", tag: server.command, detail: server.projectName,
                       titleDesign: .monospaced, action: { open(server.url.absoluteString) }) {
                    DevDot(color: TerminalColors.green)
                }
                .help("Open \(server.url.absoluteString)")
            }
        }
    }
}

struct DevProjectsCard: View {
    let projects: [GitProject]
    let open: (GitProject) -> Void

    static func detail(_ project: GitProject) -> String {
        var parts: [String] = []
        if project.changed > 0 { parts.append("\(project.changed) changed") }
        if project.untracked > 0 { parts.append("\(project.untracked) new") }
        if parts.isEmpty { parts.append("Clean") }
        if project.ahead > 0 { parts.append("↑\(project.ahead)") }
        if project.behind > 0 { parts.append("↓\(project.behind)") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        DevCard(title: "Projects", icon: "folder.fill", width: 216) {
            if projects.isEmpty {
                DevNote(text: "Projects you work on with Claude show up here with their Git status.")
            }
            ForEach(projects.prefix(3)) { project in
                DevRow(title: project.name, tag: project.branch, detail: Self.detail(project), action: { open(project) }) {
                    DevDot(color: project.isClean ? Color.white.opacity(0.25) : TerminalColors.amber)
                }
                .help("Open the terminal in \(project.name)")
            }
        }
    }
}
