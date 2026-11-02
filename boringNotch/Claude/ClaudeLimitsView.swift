//
//  ClaudeLimitsView.swift
//  Perch
//
//  The Limits tab: Claude Code and Codex side by side, each with its five-hour
//  and weekly window, when each resets, and how fresh the reading is.
//

import SwiftUI

struct ClaudeLimitsView: View {
    @ObservedObject var claude = ClaudeSessionStore.shared
    @ObservedObject var dev = DevStore.shared

    var body: some View {
        LimitsContent(claude: claude.usage, codex: dev.snapshot?.codex, isClaudeConnected: claude.isConnected)
    }
}

/// The tab drawn from plain values, so the snapshot script can render it.
struct LimitsContent: View {
    let claude: ClaudeUsageSnapshot?
    let codex: CodexLimits?
    let isClaudeConnected: Bool

    var body: some View {
        HStack(spacing: 8) {
            LimitCard(
                name: "Claude Code", mark: .claude, plan: nil, updated: claude?.cachedAt,
                fiveHour: claude?.fiveHour.map { UsageWindow(usedPercent: $0.usedPercentage, resetsAt: $0.resetsAt) },
                week: claude?.sevenDay.map { UsageWindow(usedPercent: $0.usedPercentage, resetsAt: $0.resetsAt) },
                emptyText: isClaudeConnected ? "Shows after Claude's next reply" : "Install perch-bridge to see these")
            LimitCard(
                name: "Codex", mark: .codex, plan: codex?.plan, updated: codex?.capturedAt,
                fiveHour: codex?.fiveHour, week: codex?.week,
                emptyText: "No Codex use on this Mac yet")
        }
        .frame(height: 128)
        .padding(.top, 4)
    }
}

struct LimitCard: View {
    enum Mark { case claude, codex }

    let name: String
    let mark: Mark
    let plan: String?
    let updated: Date?
    let fiveHour: UsageWindow?
    let week: UsageWindow?
    let emptyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if fiveHour == nil && week == nil {
                Spacer(minLength: 0)
                Text(emptyText)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 6)
                LimitRow(label: "5 hours", window: fiveHour, isWeek: false)
                Spacer(minLength: 6)
                LimitRow(label: "This week", window: week, isWeek: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
    }

    private var header: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle().fill(Color.white.opacity(0.12))
                switch mark {
                case .claude:
                    Text("✻").font(.system(size: 11, weight: .bold)).foregroundColor(TerminalColors.prompt)
                case .codex:
                    Image(systemName: "terminal.fill").font(.system(size: 8, weight: .bold)).foregroundColor(.white)
                }
            }
            .frame(width: 18, height: 18)
            Text(name)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(.white)
            if let plan, !plan.isEmpty {
                Text(plan.capitalized)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.65))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
            }
            Spacer(minLength: 4)
            if let updated {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(ClaudeFormatting.ageText(updated, now: context.date))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.35))
                }
            }
        }
    }
}

struct LimitRow: View {
    let label: String
    let window: UsageWindow?
    let isWeek: Bool

    private var fraction: Double { min(max((window?.usedPercent ?? 0) / 100, 0), 1) }

    /// White while there's room, amber past 70%, red past 90%.
    private var tint: Color {
        guard let used = window?.usedPercent else { return .white.opacity(0.3) }
        return used < 70 ? .white : ClaudeLimitBar.tint(for: used)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text(window.map { "\(Int($0.usedPercent.rounded()))%" } ?? "–")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundColor(tint)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule().fill(tint).frame(width: max(proxy.size.width * fraction, fraction > 0 ? 3 : 0))
                }
            }
            .frame(height: 4)
            if let resetsAt = window?.resetsAt {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(ClaudeFormatting.resetDetail(resetsAt, includeCountdown: !isWeek, now: context.date))
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }
        }
    }
}
