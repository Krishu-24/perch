//
//  main.swift
//  PerchHelper
//
//  Perch's unsandboxed companion. Perch itself runs in the App Sandbox, which
//  can't host a shell or run git, lsof and gh, so this small helper does those
//  two jobs: the drop-down terminal, and collecting the Dev tab's data.
//
//  It answers two URLs, which Perch opens:
//    perch-helper://terminal                 show or hide the drop-down's Terminal tab
//    perch-helper://terminal?show            show it (hovering the notch's Terminal tab)
//    perch-helper://terminal?cd=<folder>     show it in one of the Dev tab's projects
//    perch-helper://widgets                  show or hide the drop-down's Widgets tab
//    perch-helper://widgets?show             show it (from the notch's Dev tab)
//    perch-helper://refresh                  collect everything now, GitHub included
//

import AppKit
import Carbon.HIToolbox
import PerchDevCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let perchBundleID = "io.github.krishu-24.perch"

    private let collector = Collector()
    private let widgets = DesktopWidgets()
    /// The drop-down shares the desktop widgets' data, so both show the same thing.
    private lazy var dropdown = DropdownController(widgets: widgets.model)
    private var hotKey: HotKey?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Opening a URL launches the app if needed; the handler must be in place before launch finishes.
        NSAppleEventManager.shared().setEventHandler(
            self, andSelector: #selector(handleURL(_:reply:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // One helper at a time.
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0 != NSRunningApplication.current }
        if !others.isEmpty {
            NSApp.terminate(nil)
            return
        }

        hotKey = HotKey(keyCode: kVK_ANSI_Grave, modifiers: controlKey) { [weak self] in
            DispatchQueue.main.async { self?.dropdown.toggle() }
        }
        // The desktop widgets: data from the collector, Claude from the mod's files,
        // and whether to show them (and where) from the settings Perch writes.
        widgets.model.open = { NSWorkspace.shared.open($0) }
        widgets.model.openTerminal = { [weak self] project in self?.dropdown.show(in: project.path) }
        collector.onUpdate = { [weak self] snapshot in self?.widgets.model.snapshot = snapshot }
        refreshWidgets()
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.refreshWidgets() }
        collector.start()

        #if DEBUG
        // Debug builds only: PERCH_SNAPSHOT_DIR=<folder> opens the drop-down on each tab,
        // draws it to PNGs there, and quits.
        if let folder = ProcessInfo.processInfo.environment["PERCH_SNAPSHOT_DIR"] {
            let out = URL(fileURLWithPath: folder, isDirectory: true)
            try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [self] in
                dropdown.show(.terminal)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [self] in
                    dropdown.snapshot(to: out.appendingPathComponent("dropdown-terminal.png"))
                    dropdown.show(.widgets)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [self] in
                        dropdown.snapshot(to: out.appendingPathComponent("dropdown-widgets.png"))
                        NSApp.terminate(nil)
                    }
                }
            }
        }
        #endif

        // Quit along with Perch. Perch has no Dock icon, and macOS doesn't announce such apps
        // quitting, so look every few seconds. A helper started on its own, with no Perch
        // running yet, keeps going until it has seen Perch.
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.quitIfPerchQuit()
        }
    }

    private var hasSeenPerch = false

    private func refreshWidgets() {
        let claude = ClaudeStatus.load(from: collector.folder)
        if claude != widgets.model.claude { widgets.model.claude = claude }
        widgets.apply(WidgetSettings.load(from: collector.folder))
    }

    private func quitIfPerchQuit() {
        let isPerchRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: Self.perchBundleID).isEmpty
        if isPerchRunning {
            hasSeenPerch = true
        } else if hasSeenPerch {
            NSApp.terminate(nil)
        }
    }

    @objc private func handleURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let text = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: text), url.scheme == "perch-helper" else { return }
        switch url.host {
        case "terminal":
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            if let folder = items.first(where: { $0.name == "cd" })?.value {
                // Only folders the Dev tab lists; anything else is ignored.
                if collector.isKnownProject(folder) { dropdown.show(in: folder) }
            } else if items.contains(where: { $0.name == "show" }) {
                dropdown.show(.terminal)
            } else {
                dropdown.toggle(.terminal)
            }
        case "widgets":
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            if items.contains(where: { $0.name == "show" }) { dropdown.show(.widgets) } else { dropdown.toggle(.widgets) }
        case "refresh":
            collector.refreshNow()
        default:
            break
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
