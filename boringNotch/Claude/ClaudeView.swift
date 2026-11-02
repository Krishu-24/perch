//
//  ClaudeView.swift
//  boringNotch
//
//  The Claude tab: plan limits on the left, live sessions on the right.
//  The session row and its icon button are adapted from Vibe Notch's
//  InstanceRow and IconButton (github.com/farouqaldori/vibe-notch,
//  UI/Views/ClaudeInstancesView.swift, Apache License 2.0).
//

import SwiftUI

struct ClaudeView: View {
    @ObservedObject var store = ClaudeSessionStore.shared

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ClaudeLimitsPanel(usage: store.usage, isConnected: store.isConnected)
                .frame(width: 168)
            sessionsPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var sessionsPanel: some View {
        if !store.isConnected {
            ClaudeEmptyState(
                title: "Claude isn't connected yet",
                detail: "Install the notch-bridge mod in Claude Code. The README in this project has the two steps."
            )
        } else if store.sessions.isEmpty {
            ClaudeEmptyState(
                title: "No active sessions",
                detail: "Start a chat in Claude Code and it shows up here."
            )
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 2) {
                    ForEach(store.sessions) { session in
                        ClaudeSessionRow(session: session) { store.open(session) }
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

// MARK: - Limits

struct ClaudeLimitsPanel: View {
    let usage: ClaudeUsageSnapshot?
    let isConnected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Plan limits")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)

            ClaudeLimitBar(label: "5-hour", window: usage?.fiveHour)
            ClaudeLimitBar(label: "Weekly", window: usage?.sevenDay)

            if let cachedAt = usage?.cachedAt {
                Text("Updated \(cachedAt, style: .relative) ago")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
            } else if isConnected {
                Text("Shows after your next Claude reply")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
    }
}

struct ClaudeLimitBar: View {
    let label: String
    let window: ClaudeUsageWindow?

    private var fraction: Double {
        min(max((window?.usedPercentage ?? 0) / 100, 0), 1)
    }

    /// Green while there is room, amber past 70%, red past 90%.
    private var tint: Color {
        switch window?.usedPercentage ?? 0 {
        case ..<70: TerminalColors.green
        case ..<90: TerminalColors.amber
        default: TerminalColors.red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Text(window.map { "\($0.roundedUsedPercentage)%" } ?? "–")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(window == nil ? .white.opacity(0.3) : tint)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(tint).frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 5)
            if let resetsAt = window?.resetsAt, resetsAt > Date() {
                Text("Resets \(resetsAt, style: .relative)")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
    }
}

// MARK: - Sessions

struct ClaudeEmptyState: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            Text(detail)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ClaudeSessionRow: View {
    let session: ClaudeSession
    let onOpen: () -> Void

    @State private var isHovered = false

    private var subtitle: (lead: String?, text: String) {
        switch session.status {
        case .needsYou:
            return (session.tool, session.detail ?? "Waiting for your approval")
        case .working:
            if let tool = session.tool { return (tool, session.prompt ?? "") }
            return (nil, session.prompt ?? "Thinking…")
        case .done:
            return ("You:", session.prompt ?? session.detail ?? "Finished")
        case .idle, .ended:
            return (nil, session.status.label)
        }
    }

    private var leadColor: Color {
        session.status == .needsYou ? TerminalColors.amber.opacity(0.9) : .white.opacity(0.5)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            stateIndicator
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(session.projectName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(session.status.label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(session.status == .needsYou ? TerminalColors.amber : .white.opacity(0.3))
                }
                HStack(spacing: 4) {
                    if let lead = subtitle.lead {
                        Text(lead)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(leadColor)
                    }
                    Text(subtitle.text)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            ClaudeIconButton(icon: "arrow.up.forward.app", action: onOpen)
                .help("Open the app this session runs in")
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.white.opacity(0.06) : Color.clear)
        )
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var stateIndicator: some View {
        switch session.status {
        case .working:
            ProcessingSpinner()
        case .needsYou:
            StatusIcon(status: .needsYou, size: 12)
        case .done:
            Circle()
                .fill(TerminalColors.green)
                .frame(width: 6, height: 6)
        case .idle, .ended:
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 6, height: 6)
        }
    }
}

struct ClaudeIconButton: View {
    let icon: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isHovered ? .white.opacity(0.8) : .white.opacity(0.4))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.white.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
