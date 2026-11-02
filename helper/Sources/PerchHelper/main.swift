//
//  main.swift
//  PerchHelper
//
//  Perch's unsandboxed companion. Perch itself runs in the App Sandbox, which
//  can't host a shell or run git, lsof and gh, so this small helper does those
//  two jobs: the drop-down terminal, and collecting the Dev tab's data.
//
//  It answers two URLs, which Perch opens:
//    perch-helper://terminal                 show or hide the terminal
//    perch-helper://terminal?cd=<folder>     show it in one of the Dev tab's projects
//    perch-helper://refresh                  collect everything now, GitHub included
//

import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let perchBundleID = "io.github.krishu-24.perch"

    private let terminal = TerminalController()
    private let collector = Collector()
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
            DispatchQueue.main.async { self?.terminal.toggle() }
        }
        collector.start()

        // Quit along with Perch. Perch has no Dock icon, and macOS doesn't announce such apps
        // quitting, so look every few seconds. A helper started on its own, with no Perch
        // running yet, keeps going until it has seen Perch.
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.quitIfPerchQuit()
        }
    }

    private var hasSeenPerch = false

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
            let folder = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "cd" }?.value
            if let folder {
                // Only folders the Dev tab lists; anything else is ignored.
                if collector.isKnownProject(folder) { terminal.show(in: folder) }
            } else {
                terminal.toggle()
            }
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
