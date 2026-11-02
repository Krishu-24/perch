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
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Label("Home", systemImage: "house.fill").foregroundStyle(.gray)
                Label("Claude", systemImage: "sparkles")
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
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
    })
    try render("4-near-limit", OpenNotchFrame {
        ClaudeTabContent(sessions: Array(busySessions.prefix(2)), usage: hotUsage, isConnected: true, onOpen: open, isScrollable: false)
    })
}

_ = NSApplication.shared
MainActor.assumeIsolated {
    do { try renderAll() } catch { print(error.localizedDescription); exit(1) }
}
