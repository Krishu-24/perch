//
//  TerminalPanel.swift
//  PerchHelper
//
//  The terminal that drops out of the notch. It keeps its shell running while
//  hidden, so a toggle brings back exactly where you were.
//

import AppKit
import SwiftTerm

/// A borderless panel that can still take the keyboard.
final class TerminalPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class TerminalController: NSObject, NSWindowDelegate, LocalProcessTerminalViewDelegate {
    private static let maxSize = NSSize(width: 820, height: 480)
    private static let accent = NSColor(red: 0.85, green: 0.47, blue: 0.34, alpha: 1)  // Claude orange

    private var panel: TerminalPanel?
    private var terminal: LocalProcessTerminalView?
    private var titleLabel: NSTextField?
    private var previousApp: NSRunningApplication?
    private var isShellRunning = false
    private var startDirectory: String?

    var isVisible: Bool { panel?.isVisible == true }

    func toggle() {
        isVisible ? hide() : show()
    }

    /// Shows the terminal in `directory`: a fresh shell starts there, a running one is sent `cd`.
    func show(in directory: String) {
        if isShellRunning {
            show()
            // The leading space keeps the command out of zsh and bash history.
            terminal?.send(txt: " cd \(Self.shellQuoted(directory)) && clear\n")
        } else {
            startDirectory = directory
            show()
        }
    }

    static func shellQuoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    func show() {
        let screen = Self.notchScreen()
        if panel == nil || panel?.screen != screen { build(on: screen) }
        guard let panel, let terminal else { return }
        if !isShellRunning { startShell() }

        let frame = Self.frame(on: screen)
        previousApp = NSWorkspace.shared.frontmostApplication.flatMap {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier ? nil : $0
        }

        // Drop down out of the notch: start a little higher and clear, then settle.
        panel.setFrame(frame.offsetBy(dx: 0, dy: 24), display: false)
        panel.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(terminal)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(frame, display: true)
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        let frame = panel.frame
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(frame.offsetBy(dx: 0, dy: 24), display: true)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            panel.setFrame(frame, display: false)
            self?.previousApp?.activate()
            self?.previousApp = nil
        })
    }

    // MARK: - Building

    /// The built-in display with the notch, or the main screen on Macs without one.
    private static func notchScreen() -> NSScreen {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    /// Height of the strip the notch sits in, or of the menu bar without a notch.
    private static func topStrip(of screen: NSScreen) -> CGFloat {
        let notch = screen.safeAreaInsets.top
        return notch > 0 ? notch : max(24, screen.frame.maxY - screen.visibleFrame.maxY)
    }

    private static func frame(on screen: NSScreen) -> NSRect {
        let width = min(maxSize.width, screen.frame.width - 80)
        let height = min(maxSize.height, screen.frame.height * 0.6)
        return NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - height, width: width, height: height)
    }

    private func build(on screen: NSScreen) {
        panel?.orderOut(nil)
        let frame = Self.frame(on: screen)
        let strip = Self.topStrip(of: screen)

        let panel = TerminalPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.delegate = self

        // Black like the notch, square at the top, rounded at the bottom.
        let content = NSView(frame: NSRect(origin: .zero, size: frame.size))
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.black.cgColor
        content.layer?.cornerRadius = 22
        content.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        content.layer?.masksToBounds = true
        panel.contentView = content

        // The strip beside the notch holds the title on the left and the shortcut on the right.
        let title = Self.label(size: 11, color: NSColor(white: 1, alpha: 0.55))
        title.stringValue = "Terminal"
        title.frame = NSRect(x: 22, y: frame.height - strip + (strip - 16) / 2, width: frame.width / 2 - 140, height: 16)
        title.autoresizingMask = [.minYMargin]
        content.addSubview(title)
        titleLabel = title

        let hint = Self.label(size: 11, color: NSColor(white: 1, alpha: 0.3))
        hint.stringValue = "⌃` to hide"
        hint.alignment = .right
        hint.frame = NSRect(x: frame.width / 2 + 118, y: title.frame.minY, width: frame.width / 2 - 140, height: 16)
        hint.autoresizingMask = [.minXMargin, .minYMargin]
        content.addSubview(hint)

        let inset = NSEdgeInsets(top: strip + 8, left: 16, bottom: 14, right: 12)
        let terminalFrame = NSRect(x: inset.left, y: inset.bottom,
                                   width: frame.width - inset.left - inset.right,
                                   height: frame.height - inset.top - inset.bottom)
        let terminal = terminal ?? LocalProcessTerminalView(frame: terminalFrame)
        terminal.frame = terminalFrame
        terminal.autoresizingMask = [.width, .height]
        terminal.processDelegate = self
        terminal.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        terminal.nativeBackgroundColor = .black
        terminal.nativeForegroundColor = NSColor(white: 0.92, alpha: 1)
        terminal.caretColor = Self.accent
        terminal.optionAsMetaKey = true
        content.addSubview(terminal)

        self.panel = panel
        self.terminal = terminal
    }

    private static func label(size: CGFloat, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: size, weight: .medium)
        label.textColor = color
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }

    /// Starts your login shell in your home folder, as Terminal does.
    private func startShell() {
        guard let terminal else { return }
        let shell = ProcessInfo.processInfo.environment["SHELL"].flatMap { $0.isEmpty ? nil : $0 } ?? "/bin/zsh"
        var environment = Terminal.getEnvironmentVariables(termName: "xterm-256color", trueColor: true)
        for key in ["USER", "LOGNAME", "LANG", "SSH_AUTH_SOCK", "TMPDIR"] {
            if let value = ProcessInfo.processInfo.environment[key] { environment.append("\(key)=\(value)") }
        }
        environment.append("TERM_PROGRAM=Perch")
        terminal.startProcess(executable: shell, args: [], environment: environment,
                              execName: "-" + URL(fileURLWithPath: shell).lastPathComponent,
                              currentDirectory: startDirectory ?? NSHomeDirectory())
        startDirectory = nil
        isShellRunning = true
    }

    // MARK: - NSWindowDelegate

    /// Like a quick terminal: clicking anywhere else puts it away.
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    // MARK: - LocalProcessTerminalViewDelegate

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        titleLabel?.stringValue = title.isEmpty ? "Terminal" : title
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        guard let directory, let url = URL(string: directory) else { return }
        let path = url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        titleLabel?.stringValue = path.isEmpty ? "Terminal" : path
    }

    /// `exit` closes the panel; the next toggle starts a fresh shell.
    func processTerminated(source: TerminalView, exitCode: Int32?) {
        isShellRunning = false
        DispatchQueue.main.async { [weak self] in
            self?.hide()
            self?.terminal?.getTerminal().resetToInitialState()
        }
    }
}
