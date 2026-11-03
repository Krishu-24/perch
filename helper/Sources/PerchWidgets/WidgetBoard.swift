//
//  WidgetBoard.swift
//  PerchWidgets
//
//  Perch's desktop widgets. Each one leads with a single big number that answers
//  its question (how many projects need work, how many reviews wait on you), then
//  lists the three things behind that number, each with a status mark and the one
//  figure that matters on the right.
//

import PerchDevCore
import SwiftUI

/// What the board draws, and what clicks do.
public final class WidgetModel: ObservableObject {
    @Published public var snapshot: DevSnapshot?
    @Published public var claude = ClaudeStatus()

    public var open: (URL) -> Void = { _ in }
    public var openTerminal: (GitProject) -> Void = { _ in }

    public init() {}
}

public enum WidgetLayout {
    public static let cardWidth: CGFloat = 372
    public static let cardHeight: CGFloat = 176
    public static let gap: CGFloat = 14
    public static let boardSize = CGSize(width: cardWidth * 2 + gap, height: cardHeight * 3 + gap * 2)
}

public struct WidgetBoard: View {
    @ObservedObject var model: WidgetModel

    public init(model: WidgetModel) {
        self.model = model
    }

    public var body: some View {
        let snapshot = model.snapshot
        VStack(spacing: WidgetLayout.gap) {
            HStack(spacing: WidgetLayout.gap) {
                GitWidget(projects: snapshot?.projects ?? [], openTerminal: model.openTerminal)
                GitHubWidget(github: snapshot?.github, status: snapshot?.githubStatus ?? .failed, open: model.open)
            }
            HStack(spacing: WidgetLayout.gap) {
                ActionsWidget(github: snapshot?.github, status: snapshot?.githubStatus ?? .failed, open: model.open)
                ServersWidget(servers: snapshot?.servers ?? [], open: model.open)
            }
            HStack(spacing: WidgetLayout.gap) {
                ContributionsWidget(github: snapshot?.github)
                HStack(spacing: WidgetLayout.gap) {
                    LimitWidget(name: "Claude", mark: "✻", tint: WidgetPalette.claude,
                                fiveHour: model.claude.fiveHour, week: model.claude.week,
                                footer: Self.claudeFooter(model.claude))
                    LimitWidget(name: "Codex", mark: nil, tint: WidgetPalette.codex,
                                fiveHour: snapshot?.codex?.fiveHour, week: snapshot?.codex?.week,
                                footer: snapshot?.codex?.plan.map { "\($0.capitalized) plan" } ?? "Not used yet")
                }
                .frame(width: WidgetLayout.cardWidth)
            }
        }
        .frame(width: WidgetLayout.boardSize.width, height: WidgetLayout.boardSize.height)
        .environment(\.colorScheme, .dark)
    }

    static func claudeFooter(_ claude: ClaudeStatus) -> String {
        if claude.needsYou > 0 { return "\(claude.needsYou) needs you" }
        if claude.working > 0 { return claude.working == 1 ? "1 working" : "\(claude.working) working" }
        return "Idle"
    }
}

// MARK: - Look

public enum WidgetPalette {
    static let git = Color(red: 1.0, green: 0.62, blue: 0.1)
    static let github = Color(red: 0.52, green: 0.5, blue: 1.0)
    static let actions = Color(red: 0.27, green: 0.6, blue: 1.0)
    static let servers = Color(red: 0.24, green: 0.8, blue: 0.4)
    static let claude = Color(red: 0.85, green: 0.47, blue: 0.34)
    static let codex = Color(white: 0.92)
    static let good = Color(red: 0.24, green: 0.8, blue: 0.4)
    static let warn = Color(red: 1.0, green: 0.62, blue: 0.1)
    static let bad = Color(red: 1.0, green: 0.33, blue: 0.33)
    static let info = Color(red: 0.27, green: 0.6, blue: 1.0)
    static let quiet = Color.white.opacity(0.22)
    static let card = Color(red: 0.07, green: 0.075, blue: 0.09)
}

/// The dark card every widget sits on.
struct WidgetCard<Content: View>: View {
    var width: CGFloat = WidgetLayout.cardWidth
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(width: width, height: WidgetLayout.cardHeight, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(WidgetPalette.card.opacity(0.94)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
            .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
    }
}

struct WidgetTitle: View {
    let text: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(text).font(.system(size: 11.5, weight: .bold)).tracking(0.4).textCase(.uppercase)
        }
        .foregroundColor(tint)
        .lineLimit(1)
    }
}

/// The left column: the title, one big number, what it counts, and a small picture of it.
struct WidgetSummary<Picture: View>: View {
    let title: String
    let icon: String
    let tint: Color
    let number: String
    let caption: String
    @ViewBuilder var picture: Picture

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetTitle(text: title, icon: icon, tint: tint)
            Spacer(minLength: 6)
            Text(number)
                .font(.system(size: 40, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .font(.system(size: 12.5))
                .foregroundColor(.white.opacity(0.55))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            picture
        }
        .frame(width: 118, alignment: .leading)
    }
}

/// One line of a widget's list; the whole line is clickable when it has an action.
struct WidgetRow<Mark: View, Trailing: View>: View {
    let title: String
    let detail: String
    var action: (() -> Void)?
    @ViewBuilder var mark: Mark
    @ViewBuilder var trailing: Trailing

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            mark.frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            trailing
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(isHovered && action != nil ? 0.07 : 0)))
        .contentShape(Rectangle())
        .onTapGesture { action?() }
        .onHover { isHovered = $0 }
    }
}

struct WidgetEmpty: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.4))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Coloured capsules, one per item: the reel of statuses under the big number.
struct StatusPills: View {
    let colors: [Color]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(colors.prefix(6).enumerated()), id: \.offset) { _, color in
                Capsule().fill(color).frame(width: 22, height: 7)
            }
        }
    }
}

struct StatusDots: View {
    let colors: [Color]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(colors.prefix(8).enumerated()), id: \.offset) { _, color in
                Circle().fill(color).frame(width: 9, height: 9)
            }
        }
    }
}

func shortRepo(_ name: String) -> String {
    name.split(separator: "/").last.map(String.init) ?? name
}

func ago(_ date: Date, now: Date = Date()) -> String {
    let minutes = Int(max(0, now.timeIntervalSince(date)) / 60)
    if minutes < 1 { return "now" }
    if minutes < 60 { return "\(minutes)m ago" }
    if minutes < 24 * 60 { return "\(minutes / 60)h ago" }
    return "\(minutes / (24 * 60))d ago"
}

// MARK: - Git

struct GitWidget: View {
    let projects: [GitProject]
    let openTerminal: (GitProject) -> Void

    static func needsWork(_ project: GitProject) -> Bool {
        !project.isClean || project.ahead > 0 || project.behind > 0
    }

    static func color(_ project: GitProject) -> Color {
        if !project.isClean { return WidgetPalette.warn }
        if project.ahead > 0 || project.behind > 0 { return WidgetPalette.info }
        return WidgetPalette.quiet
    }

    var body: some View {
        WidgetCard {
            HStack(alignment: .top, spacing: 14) {
                WidgetSummary(title: "Git", icon: "arrow.triangle.branch", tint: WidgetPalette.git,
                              number: "\(projects.filter(Self.needsWork).count)",
                              caption: projects.isEmpty ? "projects yet" : "of \(projects.count) \(projects.count == 1 ? "project" : "projects") to do") {
                    StatusPills(colors: projects.map(Self.color))
                }
                VStack(spacing: 4) {
                    if projects.isEmpty {
                        WidgetEmpty(text: "Repos you use with Claude show here")
                    }
                    // Work first, then clean ones.
                    ForEach(projects.sorted { Self.needsWork($0) && !Self.needsWork($1) }.prefix(3)) { project in
                        WidgetRow(title: project.name, detail: project.branch, action: { openTerminal(project) }) {
                            mark(project)
                        } trailing: {
                            trailing(project)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
    }

    @ViewBuilder
    private func mark(_ project: GitProject) -> some View {
        let (symbol, color): (String, Color) = {
            if !project.isClean { return ("pencil.circle", WidgetPalette.warn) }
            if project.behind > 0 { return ("arrow.down.circle", WidgetPalette.info) }
            if project.ahead > 0 { return ("arrow.up.circle", WidgetPalette.info) }
            return ("checkmark.circle", WidgetPalette.good)
        }()
        Image(systemName: symbol).font(.system(size: 16, weight: .medium)).foregroundColor(color)
    }

    @ViewBuilder
    private func trailing(_ project: GitProject) -> some View {
        if Self.needsWork(project) {
            HStack(spacing: 7) {
                let edits = project.changed + project.untracked
                if edits > 0 { figure("pencil", "\(edits)", WidgetPalette.warn) }
                if project.ahead > 0 { figure("arrow.up", "\(project.ahead)", WidgetPalette.info) }
                if project.behind > 0 { figure("arrow.down", "\(project.behind)", WidgetPalette.info) }
            }
        } else {
            Text("Up to date").font(.system(size: 12, weight: .semibold)).foregroundColor(WidgetPalette.good)
        }
    }

    private func figure(_ symbol: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: symbol).font(.system(size: 10, weight: .bold)).foregroundColor(color)
            Text(value).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(.white)
        }
    }
}

// MARK: - GitHub

struct GitHubWidget: View {
    let github: GitHubSummary?
    let status: GitHubStatus
    let open: (URL) -> Void

    static func checkColor(_ state: String?) -> Color {
        switch state {
        case "SUCCESS": WidgetPalette.good
        case "FAILURE", "ERROR": WidgetPalette.bad
        case "PENDING", "EXPECTED": WidgetPalette.warn
        default: WidgetPalette.quiet
        }
    }

    var body: some View {
        WidgetCard {
            HStack(alignment: .top, spacing: 14) {
                WidgetSummary(title: "GitHub", icon: "arrow.triangle.pull", tint: WidgetPalette.github,
                              number: github.map { "\($0.reviewRequests.count)" } ?? "–",
                              caption: github == nil ? "not connected" : "to review") {
                    if let github, !github.pullRequests.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Your checks").font(.system(size: 11)).foregroundColor(.white.opacity(0.45))
                            StatusDots(colors: github.pullRequests.map { Self.checkColor($0.checks) })
                        }
                    }
                }
                VStack(spacing: 4) {
                    if let github {
                        let rows = github.reviewRequests.map { ($0, true) } + github.pullRequests.map { ($0, false) }
                        if rows.isEmpty { WidgetEmpty(text: "Nothing open or waiting on you") }
                        ForEach(Array(rows.prefix(3)), id: \.0.id) { pr, isReview in
                            WidgetRow(title: pr.title, detail: "\(ago(pr.updatedAt)) · \(shortRepo(pr.repo))#\(pr.number)",
                                      action: { URL(string: pr.url).map(open) }) {
                                if isReview {
                                    Image(systemName: "arrow.triangle.pull").font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(WidgetPalette.github)
                                } else {
                                    Circle().fill(Self.checkColor(pr.checks)).frame(width: 12, height: 12)
                                }
                            } trailing: { EmptyView() }
                        }
                    } else {
                        WidgetEmpty(text: status == .notInstalled ? "Install gh: brew install gh" : "Sign in: gh auth login")
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
    }
}

struct ActionsWidget: View {
    let github: GitHubSummary?
    let status: GitHubStatus
    let open: (URL) -> Void

    static func isFailure(_ run: WorkflowRun) -> Bool {
        ["failure", "timed_out", "startup_failure"].contains(run.conclusion ?? "")
    }

    static func color(_ run: WorkflowRun) -> Color {
        if run.isRunning { return WidgetPalette.warn }
        if isFailure(run) { return WidgetPalette.bad }
        if run.conclusion == "success" { return WidgetPalette.good }
        return WidgetPalette.quiet
    }

    var body: some View {
        let runs = github?.runs ?? []
        let running = runs.filter(\.isRunning).count
        let failed = runs.filter(Self.isFailure).count
        WidgetCard {
            HStack(alignment: .top, spacing: 14) {
                WidgetSummary(title: "Actions", icon: "bolt.horizontal.fill", tint: WidgetPalette.actions,
                              number: github == nil ? "–" : "\(running > 0 ? running : failed > 0 ? failed : runs.count)",
                              caption: github == nil ? "not connected" : running > 0 ? "running" : failed > 0 ? "failed" : "recent, passing") {
                    // One bar per recent run, newest on the right.
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(Array(runs.reversed().enumerated()), id: \.offset) { _, run in
                            RoundedRectangle(cornerRadius: 2).fill(Self.color(run))
                                .frame(width: 7, height: 22)
                        }
                    }
                    .frame(height: 26, alignment: .bottom)
                }
                VStack(spacing: 4) {
                    if github == nil {
                        WidgetEmpty(text: "Connect GitHub to see runs")
                    } else if runs.isEmpty {
                        WidgetEmpty(text: "No recent runs in your projects")
                    }
                    ForEach(Array(runs.prefix(3).enumerated()), id: \.offset) { _, run in
                        WidgetRow(title: run.workflow, detail: "\(shortRepo(run.repo)) · \(run.branch)",
                                  action: { URL(string: run.url).map(open) }) {
                            mark(run)
                        } trailing: {
                            VStack(alignment: .trailing, spacing: 1) {
                                TimelineView(.periodic(from: .now, by: 1)) { context in
                                    Text(run.isRunning ? Self.elapsed(run.createdAt, now: context.date) : ago(run.createdAt, now: context.date))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(run.isRunning ? WidgetPalette.warn : .white.opacity(0.5))
                                }
                                Text(run.isRunning ? "Running" : Self.isFailure(run) ? "Failed" : run.conclusion == "success" ? "Passed" : (run.conclusion ?? "").capitalized)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(run.isRunning ? WidgetPalette.warn : Self.isFailure(run) ? WidgetPalette.bad : .white.opacity(0.5))
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
    }

    static func elapsed(_ start: Date, now: Date) -> String {
        let seconds = Int(max(0, now.timeIntervalSince(start)))
        return seconds >= 3600 ? "\(seconds / 3600):\(String(format: "%02d", seconds % 3600 / 60)):\(String(format: "%02d", seconds % 60))"
            : "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }

    @ViewBuilder
    private func mark(_ run: WorkflowRun) -> some View {
        if run.isRunning {
            Text("✻").font(.system(size: 15, weight: .bold)).foregroundColor(WidgetPalette.warn)
        } else {
            Image(systemName: Self.isFailure(run) ? "xmark.circle.fill" : run.conclusion == "success" ? "checkmark.circle.fill" : "minus.circle.fill")
                .font(.system(size: 15)).foregroundColor(Self.color(run))
        }
    }
}

// MARK: - Dev servers

struct ServersWidget: View {
    let servers: [DevServer]
    let open: (URL) -> Void

    var body: some View {
        WidgetCard {
            HStack(alignment: .top, spacing: 14) {
                WidgetSummary(title: "Dev servers", icon: "server.rack", tint: WidgetPalette.servers,
                              number: "\(servers.count)", caption: "running") {
                    StatusDots(colors: servers.map { _ in WidgetPalette.servers })
                }
                VStack(spacing: 5) {
                    if servers.isEmpty { WidgetEmpty(text: "Start a dev server and it shows here") }
                    ForEach(servers.prefix(3)) { server in
                        WidgetRow(title: server.projectName, detail: server.summary ?? server.command,
                                  action: { open(server.url) }) {
                            Image(systemName: "apple.terminal").font(.system(size: 13)).foregroundColor(.white.opacity(0.55))
                        } trailing: {
                            Text(verbatim: ":\(server.port)")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(WidgetPalette.servers)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Capsule().fill(WidgetPalette.servers.opacity(0.14)))
                        }
                        .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.04)))
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
    }
}

// MARK: - Contributions

struct ContributionsWidget: View {
    let github: GitHubSummary?

    static let weeks = 24
    static let cell: CGFloat = 11
    static let gap: CGFloat = 3

    static func color(_ count: Int, max: Int) -> Color {
        guard count > 0, max > 0 else { return Color.white.opacity(0.07) }
        let share = Double(count) / Double(max)
        return WidgetPalette.good.opacity(share <= 0.25 ? 0.35 : share <= 0.5 ? 0.55 : share <= 0.75 ? 0.78 : 1)
    }

    var body: some View {
        WidgetCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(github.map { $0.totalContributions.formatted() } ?? "–")
                        .font(.system(size: 30, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                    Text(github == nil ? "contributions · connect GitHub" : "contributions in the last year")
                        .font(.system(size: 12.5))
                        .foregroundColor(.white.opacity(0.55))
                    Spacer(minLength: 0)
                    if let streak = github?.currentStreak, streak > 0 {
                        Label("\(streak)d", systemImage: "flame.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(WidgetPalette.warn)
                    }
                }
                grid
            }
        }
    }

    private var grid: some View {
        let days = Array((github?.days ?? []).suffix(Self.weeks * 7))
        let maxCount = days.map(\.count).max() ?? 0
        let size = CGSize(width: CGFloat(Self.weeks) * (Self.cell + Self.gap) - Self.gap, height: 7 * (Self.cell + Self.gap) - Self.gap)
        return Canvas { context, _ in
            for slot in 0..<(Self.weeks * 7) {
                // Fill from the end so today sits in the last column.
                let index = days.count - (Self.weeks * 7) + slot
                let count = index >= 0 && index < days.count ? days[index].count : 0
                let rect = CGRect(x: CGFloat(slot / 7) * (Self.cell + Self.gap), y: CGFloat(slot % 7) * (Self.cell + Self.gap),
                                  width: Self.cell, height: Self.cell)
                context.fill(Path(roundedRect: rect, cornerRadius: 2.5), with: .color(Self.color(count, max: maxCount)))
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Limits

struct LimitWidget: View {
    let name: String
    let mark: String?
    let tint: Color
    let fiveHour: UsageWindow?
    let week: UsageWindow?
    let footer: String

    static func color(_ used: Double) -> Color {
        used >= 90 ? WidgetPalette.bad : used >= 70 ? WidgetPalette.warn : .white
    }

    var body: some View {
        WidgetCard(width: (WidgetLayout.cardWidth - WidgetLayout.gap) / 2) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    if let mark {
                        Text(mark).font(.system(size: 12, weight: .bold)).foregroundColor(tint)
                    } else {
                        Image(systemName: "terminal.fill").font(.system(size: 10, weight: .bold)).foregroundColor(tint)
                    }
                    Text(name).font(.system(size: 11.5, weight: .bold)).tracking(0.4).textCase(.uppercase).foregroundColor(tint)
                }
                Spacer(minLength: 4)
                Text(fiveHour.map { "\(Int($0.usedPercent.rounded()))%" } ?? "–")
                    .font(.system(size: 34, weight: .medium, design: .rounded))
                    .foregroundColor(fiveHour.map { Self.color($0.usedPercent) } ?? .white.opacity(0.4))
                Text("of 5 hours")
                    .font(.system(size: 11.5)).foregroundColor(.white.opacity(0.5))
                Spacer(minLength: 6)
                bar(fiveHour)
                HStack {
                    Text("Week").font(.system(size: 10.5)).foregroundColor(.white.opacity(0.45))
                    Spacer()
                    Text(week.map { "\(Int($0.usedPercent.rounded()))%" } ?? "–")
                        .font(.system(size: 10.5, weight: .semibold)).foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 6)
                Text(footer).font(.system(size: 10.5, weight: .medium)).foregroundColor(.white.opacity(0.45)).lineLimit(1)
                    .padding(.top, 2)
            }
        }
    }

    private func bar(_ window: UsageWindow?) -> some View {
        let fraction = min(max((window?.usedPercent ?? 0) / 100, 0), 1)
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule().fill(Self.color(window?.usedPercent ?? 0)).frame(width: max(proxy.size.width * fraction, fraction > 0 ? 3 : 0))
            }
        }
        .frame(height: 4)
    }
}
