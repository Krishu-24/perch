//
//  ClaudeLiveActivity.swift
//  boringNotch
//
//  What the closed notch shows while Claude works: the spinner, or an amber
//  hand when a session needs you, on the left; the five-hour usage, or how many
//  sessions are waiting, on the right. Laid out like MusicLiveActivity.
//

import SwiftUI

struct ClaudeLiveActivity: View {
    let needsYouCount: Int
    let workingCount: Int
    let fiveHour: ClaudeUsageWindow?
    /// The closed notch's height; each side gets a square this tall, less 12.
    let notchHeight: CGFloat
    /// The black gap the physical notch covers.
    let notchWidth: CGFloat

    private var side: CGFloat { max(0, notchHeight - 12) }

    var body: some View {
        HStack {
            leading
                .frame(width: side, height: side)

            Rectangle()
                .fill(.black)
                .frame(width: notchWidth)

            trailing
                .frame(width: side, height: side)
        }
        .frame(height: notchHeight, alignment: .center)
    }

    @ViewBuilder
    private var leading: some View {
        if needsYouCount > 0 {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(TerminalColors.amber)
                .modifier(ClaudePulse())
        } else {
            ClaudeSpark()
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if needsYouCount > 1 {
            Text("\(needsYouCount)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(TerminalColors.amber)
        } else if let fiveHour {
            Text("\(fiveHour.roundedUsedPercentage)%")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(ClaudeLimitBar.tint(for: fiveHour.usedPercentage))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        } else if workingCount > 1 {
            Text("\(workingCount)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

/// Claude's spark turning steadily: large enough to read at closed-notch size,
/// where the row spinner's smallest frame almost vanishes.
struct ClaudeSpark: View {
    @State private var angle: Double = 0

    var body: some View {
        Text("✻")
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(TerminalColors.prompt)
            .rotationEffect(.degrees(angle))
            .onAppear {
                withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
    }
}

/// A slow fade in and out that draws the eye without moving anything.
struct ClaudePulse: ViewModifier {
    @State private var isDim = false

    func body(content: Content) -> some View {
        content
            .opacity(isDim ? 0.45 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    isDim = true
                }
            }
    }
}
