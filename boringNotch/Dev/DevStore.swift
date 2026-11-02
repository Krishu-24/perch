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
        openHelper("perch-helper://terminal")
    }

    /// Opens the terminal in one of the listed projects.
    func openTerminal(in project: GitProject) {
        var components = URLComponents(string: "perch-helper://terminal")!
        components.queryItems = [URLQueryItem(name: "cd", value: project.path)]
        if let url = components.url { NSWorkspace.shared.open(url) }
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
