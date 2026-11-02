//
//  TerminalPanel.swift
//  PerchHelper
//
//  The terminal that drops out of the notch. It keeps its shell running while
//  hidden, so a toggle brings back exactly where you were.
//
//  It sits above the notch and the menu bar's icons, so nothing draws over it, and
//  tells Perch when it shows and hides, so the notch stays shut underneath it.
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

    /// Above Perch's notch (main menu + 3) and the menu bar's icons (status bar), below menus and alerts.
    static let level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 4)

    /// Posted to Perch, without a userInfo, so its sandbox lets them through.
    static let didShowNotification = Notification.Name("io.github.krishu-24.perch.terminal.didShow")
    static let didHideNotification = Notification.Name("io.github.krishu-24.perch.terminal.didHide")
    /// Asks Perch to open the notch on a tab; the object is the tab's name ("home", "limits", "claude", "dev").
    static let openTabNotification = Notification.Name("io.github.krishu-24.perch.openTab")

    private var panel: TerminalPanel?
    private var terminal: LocalProcessTerminalView?
    private var titleLabel: NSTextField?
    private var tabStrip: TerminalTabStrip?
    private var previousApp: NSRunningApplication?
    private var isShellRunning = false
    private var startDirectory: String?

    /// Bumped by every show, so a hide that's still animating doesn't order the panel out afterwards.
    private var hideToken = 0
    private var isHiding = false

    var isVisible: Bool { panel?.isVisible == true && !isHiding }

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
        if isVisible, let panel {
            // Already down: just take the keyboard back, and keep the app to return to.
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(terminal)
            return
        }
        hideToken += 1
        isHiding = false

        let screen = Self.notchScreen()
        if panel == nil || panel?.screen != screen { build(on: screen) }
        guard let panel, let terminal else { return }
        if !isShellRunning { startShell() }

        let frame = Self.frame(on: screen)
        if let front = NSWorkspace.shared.frontmostApplication, front.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = front
        }

        // Drop down out of the notch: start a little higher and clear, then settle.
        panel.setFrame(frame.offsetBy(dx: 0, dy: 24), display: false)
        panel.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(terminal)
        tabStrip?.arm()
        Self.announce(Self.didShowNotification)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(frame, display: true)
            panel.animator().alphaValue = 1
        }
    }

    /// Puts the terminal away and opens the notch on another tab, from the tabs along its top strip.
    private func switchToTab(_ name: String) {
        hide {
            DistributedNotificationCenter.default().postNotificationName(
                TerminalController.openTabNotification, object: name, userInfo: nil, deliverImmediately: true)
        }
    }

    func hide(then completion: (() -> Void)? = nil) {
        guard let panel, isVisible else { return }
        isHiding = true
        let token = hideToken
        let frame = Self.frame(on: panel.screen ?? Self.notchScreen())
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(frame.offsetBy(dx: 0, dy: 24), display: true)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            // Shown again while this was animating: leave it up.
            guard let self, self.hideToken == token else { return }
            panel.orderOut(nil)
            panel.setFrame(frame, display: false)
            self.isHiding = false
            self.previousApp?.activate()
            self.previousApp = nil
            TerminalController.announce(TerminalController.didHideNotification)
            completion?()
        })
    }

    private static func announce(_ name: Notification.Name) {
        DistributedNotificationCenter.default().postNotificationName(name, object: nil, userInfo: nil, deliverImmediately: true)
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

    /// The notch's left and right edges in the panel's coordinates; a 200-point gap on Macs without one.
    private static func notchEdges(on screen: NSScreen, panelWidth: CGFloat) -> (left: CGFloat, right: CGFloat) {
        let offset = (screen.frame.width - panelWidth) / 2
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea,
           left.width > 0, right.width > 0, left.width + right.width < screen.frame.width {
            // Each area runs from the screen's edge to the notch's.
            return (left.width - offset, screen.frame.width - right.width - offset)
        }
        return (panelWidth / 2 - 100, panelWidth / 2 + 100)
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
        panel.level = Self.level
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.acceptsMouseMovedEvents = true

        // Black like the notch, square at the top, rounded at the bottom.
        let content = NSView(frame: NSRect(origin: .zero, size: frame.size))
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.black.cgColor
        content.layer?.cornerRadius = 22
        content.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        content.layer?.masksToBounds = true
        panel.contentView = content

        // The strip beside the notch: the notch's tabs on the left, where the open notch shows
        // them, and the title and shortcut on the right.
        let notch = Self.notchEdges(on: screen, panelWidth: frame.width)
        let tabsX = max(16, notch.left - 10 - TerminalTabStrip.width)
        // The terminal below spans the whole panel; in the strip's coordinates that starts left of it.
        let tabs = TerminalTabStrip(
            frame: NSRect(x: tabsX, y: frame.height - strip, width: TerminalTabStrip.width, height: strip),
            contentMinX: -tabsX, contentMaxX: frame.width - tabsX)
        tabs.autoresizingMask = [.minYMargin]
        tabs.onSelect = { [weak self] name in self?.switchToTab(name) }
        content.addSubview(tabs)
        tabStrip = tabs

        let hintWidth: CGFloat = 76
        let rightStart = notch.right + 18
        let title = Self.label(size: 11, color: NSColor(white: 1, alpha: 0.55))
        title.stringValue = "Terminal"
        title.frame = NSRect(x: rightStart, y: frame.height - strip + (strip - 16) / 2,
                             width: max(40, frame.width - 22 - hintWidth - 8 - rightStart), height: 16)
        title.autoresizingMask = [.minYMargin]
        content.addSubview(title)
        titleLabel = title

        let hint = Self.label(size: 11, color: NSColor(white: 1, alpha: 0.3))
        hint.stringValue = "⌃` to hide"
        hint.alignment = .right
        hint.frame = NSRect(x: frame.width - 22 - hintWidth, y: title.frame.minY, width: hintWidth, height: 16)
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
