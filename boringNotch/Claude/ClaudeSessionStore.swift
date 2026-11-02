//
//  ClaudeSessionStore.swift
//  boringNotch
//
//  Reads what the perch-bridge Claude Code mod writes:
//    ~/Library/Application Support/Perch/sessions/<id>.json
//    ~/Library/Application Support/Perch/limits.json
//

import AppKit
import Foundation

enum ClaudeSessionStatus: String, Decodable {
    case idle
    case working
    case needsYou = "needs_you"
    case done
    case ended

    /// Lower sorts first: what needs the person comes to the top.
    var rank: Int {
        switch self {
        case .needsYou: 0
        case .working: 1
        case .done: 2
        case .idle: 3
        case .ended: 4
        }
    }

    var label: String {
        switch self {
        case .needsYou: "Needs you"
        case .working: "Working"
        case .done: "Your turn"
        case .idle: "Idle"
        case .ended: "Ended"
        }
    }
}

struct ClaudeSession: Decodable, Identifiable, Equatable {
    let sessionId: String
    let cwd: String
    let surface: String?
    let status: ClaudeSessionStatus
    let prompt: String?
    let tool: String?
    let detail: String?
    /// Milliseconds since 1970, from the mod's clock.
    let updatedAt: Double

    var id: String { sessionId }

    var projectName: String {
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        return name.isEmpty ? cwd : name
    }

    var updated: Date { Date(timeIntervalSince1970: updatedAt / 1000) }
}

@MainActor
final class ClaudeSessionStore: ObservableObject {
    static let shared = ClaudeSessionStore()

    @Published private(set) var sessions: [ClaudeSession] = []
    @Published private(set) var usage: ClaudeUsageSnapshot?
    /// False until the mod has written anything, so the tab can explain the setup.
    @Published private(set) var isConnected = false

    /// The sandbox points NSHomeDirectory at the app's container, so read the real one.
    static let folder: URL = {
        let home = getpwuid(getuid()).flatMap { String(validatingCString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        return URL(fileURLWithPath: home)
            .appendingPathComponent("Library/Application Support/Perch", isDirectory: true)
    }()

    private static let sessionsFolder = folder.appendingPathComponent("sessions", isDirectory: true)
    private static let limitsFile = folder.appendingPathComponent("limits.json")

    /// A finished or idle session drops off the list after this long.
    nonisolated private static let quietTimeout: TimeInterval = 30 * 60
    /// A session still marked working or waiting with no news for this long is hidden.
    nonisolated private static let staleTimeout: TimeInterval = 2 * 60 * 60
    /// Files of sessions that ended or went quiet are deleted after this long.
    nonisolated private static let cleanupAge: TimeInterval = 24 * 60 * 60

    private var timer: Timer?

    var needsYouCount: Int { sessions.filter { $0.status == .needsYou }.count }
    var workingCount: Int { sessions.filter { $0.status == .working }.count }

    private init() {
        reload()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    func reload() {
        let snapshot = Self.readSessions(in: Self.sessionsFolder)
        if snapshot != sessions { sessions = snapshot }

        let limits = ClaudeUsageLoader.load(from: Self.limitsFile)
        if limits != usage { usage = limits }

        let connected = FileManager.default.fileExists(atPath: Self.folder.path)
        if connected != isConnected { isConnected = connected }
    }

    /// Brings the app the session runs in to the front: the Claude app for a
    /// desktop session, otherwise the frontmost terminal Claude Code was started from.
    func open(_ session: ClaudeSession) {
        let claudeApp = "com.anthropic.claudefordesktop"
        if session.surface == "desktop" || session.surface == nil,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: claudeApp).first {
            app.activate()
            return
        }
        let terminals = ["com.mitchellh.ghostty", "com.googlecode.iterm2", "com.apple.Terminal", "dev.warp.Warp-Stable", "com.github.wez.wezterm"]
        for id in terminals {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first {
                app.activate()
                return
            }
        }
    }

    /// The sessions worth showing, needs-you first; deletes files too old to matter.
    nonisolated static func readSessions(in sessionsFolder: URL, now: Date = Date()) -> [ClaudeSession] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: sessionsFolder, includingPropertiesForKeys: nil) else {
            return []
        }

        let decoder = JSONDecoder()
        var result: [ClaudeSession] = []

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let session = try? decoder.decode(ClaudeSession.self, from: data) else { continue }

            let age = now.timeIntervalSince(session.updated)
            if age > cleanupAge {
                try? fm.removeItem(at: file)
                continue
            }
            switch session.status {
            case .ended:
                continue
            case .done, .idle:
                // The desktop app starts sessions ahead of use; show one once it has a prompt.
                if age > quietTimeout || session.prompt == nil { continue }
            case .working, .needsYou:
                // A session that quit without saying so stops reporting.
                if age > staleTimeout { continue }
            }
            result.append(session)
        }

        return result.sorted {
            $0.status.rank != $1.status.rank ? $0.status.rank < $1.status.rank : $0.updatedAt > $1.updatedAt
        }
    }
}
