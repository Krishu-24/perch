//
//  DevStore.swift
//  Perch
//
//  Reads what Perch Helper collects (dev.json), starts the helper, and asks it to
//  show the terminal. Perch is sandboxed, so it never runs git, lsof or gh itself;
//  it only opens perch-helper:// URLs and web links.
//

import AppKit
import Foundation

@MainActor
final class DevStore: ObservableObject {
    static let shared = DevStore()

    @Published private(set) var snapshot: DevSnapshot?
    @Published private(set) var isHelperRunning = false
    @Published private(set) var widgetSettings = WidgetSettings.load(from: ClaudeSessionStore.folder)
    /// Whether the helper's terminal is down. The notch stays shut while it is, since the terminal covers it.
    @Published private(set) var isTerminalVisible = false
    /// When Perch last asked for the terminal, before the helper has said it's down.
    private var terminalRequestedAt: Date?

    /// The helper posts these, without a userInfo, as the terminal shows and hides.
    private static let terminalDidShow = Notification.Name("io.github.krishu-24.perch.terminal.didShow")
    private static let terminalDidHide = Notification.Name("io.github.krishu-24.perch.terminal.didHide")
    /// The terminal's own row of tabs asks for one; the object is its name ("home", "limits", "claude", "dev").
    private static let openTab = Notification.Name("io.github.krishu-24.perch.openTab")

    /// A tab the terminal asked the notch to open, once it had put itself away.
    struct TabRequest: Equatable {
        let name: String
        let id = UUID()
    }
    @Published private(set) var tabRequest: TabRequest?

    static let helperBundleID = "io.github.krishu-24.perch.helper"
    private static let file = ClaudeSessionStore.folder.appendingPathComponent(DevSnapshot.fileName)

    private var timer: Timer?

    /// Where Perch looks for its helper: inside Perch.app first, then Applications.
    static var helperURL: URL? {
        let candidates = [
            Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LoginItems/Perch Helper.app"),
            URL(fileURLWithPath: "/Applications/Perch Helper.app"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private init() {
        reload()
        let center = DistributedNotificationCenter.default()
        _ = center.addObserver(forName: Self.terminalDidShow, object: nil, queue: .main) { _ in
            Task { @MainActor in DevStore.shared.setTerminalVisible(true) }
        }
        _ = center.addObserver(forName: Self.terminalDidHide, object: nil, queue: .main) { _ in
            Task { @MainActor in DevStore.shared.setTerminalVisible(false) }
        }
        _ = center.addObserver(forName: Self.openTab, object: nil, queue: .main) { notification in
            guard let name = notification.object as? String else { return }
            Task { @MainActor in DevStore.shared.requestTab(name) }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    func reload() {
        let running = !NSRunningApplication.runningApplications(withBundleIdentifier: Self.helperBundleID).isEmpty
        if running != isHelperRunning { isHelperRunning = running }

        guard let data = try? Data(contentsOf: Self.file),
              let decoded = try? DevSnapshot.decoder.decode(DevSnapshot.self, from: data) else { return }
        if decoded != snapshot { snapshot = decoded }
    }

    /// Starts the helper in the background if it isn't running.
    func startHelper() {
        guard !isHelperRunning, let url = Self.helperURL else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            Task { @MainActor in DevStore.shared.reload() }
        }
    }

    func toggleTerminal() {
        terminalRequestedAt = Date()
        openHelper("perch-helper://terminal")
    }

    /// Drops the terminal down; unlike toggling, never puts it away.
    func showTerminal() {
        terminalRequestedAt = Date()
        openHelper("perch-helper://terminal?show")
    }

    /// True while the terminal is down, or about to be: the notch shouldn't open beneath it.
    var isTerminalCoveringNotch: Bool {
        isTerminalVisible || (terminalRequestedAt.map { Date().timeIntervalSince($0) < 3 } ?? false)
    }

    private func requestTab(_ name: String) {
        // The terminal has gone by the time it asks, whichever notification arrives first.
        setTerminalVisible(false)
        tabRequest = TabRequest(name: name)
    }

    private func setTerminalVisible(_ visible: Bool) {
        terminalRequestedAt = nil
        if visible != isTerminalVisible { isTerminalVisible = visible }
    }

    /// Opens the terminal in one of the listed projects.
    func openTerminal(in project: GitProject) {
        terminalRequestedAt = Date()
        var components = URLComponents(string: "perch-helper://terminal")!
        components.queryItems = [URLQueryItem(name: "cd", value: project.path)]
        if let url = components.url { NSWorkspace.shared.open(url) }
    }

    /// Saves the desktop widget settings; Perch Helper picks them up within a few seconds.
    func saveWidgetSettings(_ settings: WidgetSettings) {
        widgetSettings = settings
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(settings) else { return }
        try? FileManager.default.createDirectory(at: ClaudeSessionStore.folder, withIntermediateDirectories: true)
        try? data.write(to: ClaudeSessionStore.folder.appendingPathComponent(WidgetSettings.fileName), options: .atomic)
    }

    /// Asks the helper to collect everything now, GitHub included.
    func refresh() {
        openHelper("perch-helper://refresh")
    }

    func open(_ link: String) {
        if let url = URL(string: link), ["https", "http"].contains(url.scheme) {
            NSWorkspace.shared.open(url)
        }
    }

    private func openHelper(_ link: String) {
        if !isHelperRunning { startHelper() }
        if let url = URL(string: link) { NSWorkspace.shared.open(url) }
    }
}
