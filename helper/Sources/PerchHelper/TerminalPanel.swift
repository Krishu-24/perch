//
//  TerminalPanel.swift
//  PerchHelper
//
//  The drop-down that comes out of the notch. Its top strip carries the notch's tabs
//  plus Widgets: Terminal and Widgets switch inside the drop-down, and the notch's own
//  tabs put it away and open the notch on that tab. Both of its tabs stay alive while
//  you switch, and the shell keeps running while it's hidden, so a toggle brings back
//  exactly where you were.
//
//  It sits above the notch and the menu bar's icons, so nothing draws over it, and
//  tells Perch when it shows and hides, so the notch stays shut underneath it.
//

import AppKit
import PerchWidgets
import SwiftTerm
import SwiftUI

/// A borderless panel that can still take the keyboard.
final class TerminalPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// What the drop-down shows. Each matches a tab in its strip.
enum DropdownTab: String {
    case terminal, widgets
}

/// The widget board, shrunk to fit if the screen is small.
struct DropdownWidgets: View {
    let model: WidgetModel
    let scale: CGFloat

    var body: some View {
        WidgetBoard(model: model)
            .scaleEffect(scale, anchor: .top)
            .frame(width: WidgetLayout.boardSize.width * scale, height: WidgetLayout.boardSize.height * scale, alignment: .top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// Takes the first click, so a widget responds straight away.
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class DropdownController: NSObject, NSWindowDelegate, LocalProcessTerminalViewDelegate {
    private static let accent = NSColor(red: 0.85, green: 0.47, blue: 0.34, alpha: 1)  // Claude orange
    /// Space around the terminal and the widgets, below the strip.
    private static let inset = NSEdgeInsets(top: 8, left: 16, bottom: 16, right: 16)

    /// Above Perch's notch (main menu + 3) and the menu bar's icons (status bar), below menus and alerts.
    static let level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 4)

    /// Posted to Perch, without a userInfo, so its sandbox lets them through.
    static let didShowNotification = Notification.Name("io.github.krishu-24.perch.terminal.didShow")
    static let didHideNotification = Notification.Name("io.github.krishu-24.perch.terminal.didHide")
    /// Asks Perch to open the notch on a tab; the object is the tab's name ("home", "limits", "claude", "dev").
    static let openTabNotification = Notification.Name("io.github.krishu-24.perch.openTab")

    let widgets: WidgetModel
    private var panel: TerminalPanel?
    private var terminal: LocalProcessTerminalView?
    private var widgetView: NSView?
    private var titleLabel: NSTextField?
    private var tabStrip: TerminalTabStrip?
    private var previousApp: NSRunningApplication?
    private var isShellRunning = false
    private var startDirectory: String?
    /// The tab showing now, and the one Control-` comes back to.
    private var tab: DropdownTab = .terminal
    private var terminalTitle = "Terminal"

    /// Bumped by every show, so a hide that's still animating doesn't order the panel out afterwards.
    private var hideToken = 0
    private var isHiding = false

    var isVisible: Bool { panel?.isVisible == true && !isHiding }

    init(widgets: WidgetModel) {
        self.widgets = widgets
    }

    /// Control-`: shows the drop-down on the tab you used last, or puts it away.
    func toggle() {
        isVisible ? hide() : show(tab)
    }

    /// Shows the drop-down on `tab`; if it's already showing that tab, puts it away.
    func toggle(_ tab: DropdownTab) {
        if isVisible && self.tab == tab { hide() } else { show(tab) }
    }

    /// Shows the terminal in `directory`: a fresh shell starts there, a running one is sent `cd`.
    func show(in directory: String) {
        if isShellRunning {
            show(.terminal)
            // The leading space keeps the command out of zsh and bash history.
            terminal?.send(txt: " cd \(Self.shellQuoted(directory)) && clear\n")
        } else {
            startDirectory = directory
            show(.terminal)
        }
    }

    static func shellQuoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    func show(_ tab: DropdownTab) {
        if isVisible, let panel {
            // Already down: switch tabs, take the keyboard back, and keep the app to return to.
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            select(tab)
            return
        }
        hideToken += 1
        isHiding = false

        let screen = Self.notchScreen()
        if panel == nil || panel?.screen != screen { build(on: screen) }
        guard let panel else { return }

        let frame = Self.frame(on: screen)
        if let front = NSWorkspace.shared.frontmostApplication, front.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = front
        }

        // Drop down out of the notch: start a little higher and clear, then settle.
        panel.setFrame(frame.offsetBy(dx: 0, dy: 24), display: false)
        panel.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        select(tab)
        tabStrip?.arm()
        Self.announce(Self.didShowNotification)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(frame, display: true)
            panel.animator().alphaValue = 1
        }
    }

    /// Switches between Terminal and Widgets; the other keeps its state.
    private func select(_ tab: DropdownTab) {
        self.tab = tab
        terminal?.isHidden = tab != .terminal
        widgetView?.isHidden = tab != .widgets
        tabStrip?.setCurrent(tab.rawValue)
        titleLabel?.stringValue = tab == .terminal ? terminalTitle : "Widgets"
        if tab == .terminal {
            if !isShellRunning { startShell() }
            if let terminal { panel?.makeFirstResponder(terminal) }
        } else {
            panel?.makeFirstResponder(nil)
        }
    }

    /// From the strip: Terminal and Widgets switch here; the notch's other tabs put the
    /// drop-down away and open the notch on that tab.
    private func pick(_ name: String) {
        if let tab = DropdownTab(rawValue: name) {
            select(tab)
        } else {
            hide {
                DistributedNotificationCenter.default().postNotificationName(
                    DropdownController.openTabNotification, object: name, userInfo: nil, deliverImmediately: true)
            }
        }
    }

    #if DEBUG
    /// Debug builds only: draws the drop-down's own window to a PNG, so its layout can be
    /// checked without a screenshot (which needs Screen Recording permission), and saves the
    /// terminal's visible text to a .txt beside it.
    func snapshot(to url: URL) {
        guard let view = panel?.contentView, let layer = view.layer else { return }
        // The layer tree, so layer colours (the terminal's black) come out too.
        let scale = panel?.backingScaleFactor ?? 2
        let size = NSSize(width: view.bounds.width * scale, height: view.bounds.height * scale)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: rep) else { return }
        context.cgContext.scaleBy(x: scale, y: scale)
        layer.render(in: context.cgContext)
        // The terminal's own pixels don't come through a layer render (it shows as blank), so its
        // visible text is saved alongside instead.
        try? rep.representation(using: .png, properties: [:])?.write(to: url)

        // And what the terminal shows, as text.
        if let terminal, tab == .terminal {
            let screen = terminal.getTerminal()
            let lines = (0..<screen.rows).compactMap { screen.getLine(row: $0)?.translateToString(trimRight: true) }
            try? lines.joined(separator: "\n").write(to: url.deletingPathExtension().appendingPathExtension("txt"),
                                                     atomically: true, encoding: .utf8)
        }
    }
    #endif

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
            DropdownController.announce(DropdownController.didHideNotification)
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

    /// Big enough for the widget board at full size, but never more than about 70% of the screen.
    private static func frame(on screen: NSScreen) -> NSRect {
        let strip = topStrip(of: screen)
        let wanted = NSSize(width: WidgetLayout.boardSize.width + inset.left + inset.right + 30,
                            height: strip + inset.top + WidgetLayout.boardSize.height + inset.bottom)
        let width = min(wanted.width, screen.frame.width - 80)
        let height = min(wanted.height, screen.frame.height * 0.72)
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
        content.layer?.cornerRadius = 24
        content.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        content.layer?.masksToBounds = true
        panel.contentView = content

        // The strip beside the notch: the tabs on the left, where the open notch shows them,
        // and the title and shortcut on the right.
        let notch = Self.notchEdges(on: screen, panelWidth: frame.width)
        let tabsX = max(16, notch.left - 10 - TerminalTabStrip.width)
        // The content below spans the whole panel; in the strip's coordinates that starts left of it.
        let tabs = TerminalTabStrip(
            frame: NSRect(x: tabsX, y: frame.height - strip, width: TerminalTabStrip.width, height: strip),
            contentMinX: -tabsX, contentMaxX: frame.width - tabsX)
        tabs.autoresizingMask = [.minYMargin]
        tabs.onSelect = { [weak self] name in self?.pick(name) }
        content.addSubview(tabs)
        tabStrip = tabs

        let hintWidth: CGFloat = 76
        let rightStart = notch.right + 18
        let title = Self.label(size: 11, color: NSColor(white: 1, alpha: 0.55))
        title.stringValue = terminalTitle
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

        let inset = Self.inset
        let body = NSRect(x: inset.left, y: inset.bottom,
                          width: frame.width - inset.left - inset.right,
                          height: frame.height - strip - inset.top - inset.bottom)

        let terminal = terminal ?? LocalProcessTerminalView(frame: body)
        terminal.frame = body
        terminal.autoresizingMask = [.width, .height]
        terminal.processDelegate = self
        terminal.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        terminal.nativeBackgroundColor = .black
        terminal.nativeForegroundColor = NSColor(white: 0.92, alpha: 1)
        terminal.caretColor = Self.accent
        terminal.optionAsMetaKey = true
        content.addSubview(terminal)

        let scale = min(1, body.width / WidgetLayout.boardSize.width, body.height / WidgetLayout.boardSize.height)
        let board = FirstClickHostingView(rootView: DropdownWidgets(model: widgets, scale: scale))
        board.frame = body
        board.autoresizingMask = [.width, .height]
        content.addSubview(board)

        self.panel = panel
        self.terminal = terminal
        self.widgetView = board
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

    private func setTerminalTitle(_ text: String) {
        terminalTitle = text
        if tab == .terminal { titleLabel?.stringValue = text }
    }

    // MARK: - NSWindowDelegate

    /// Like a quick terminal: clicking anywhere else puts it away.
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    // MARK: - LocalProcessTerminalViewDelegate

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        setTerminalTitle(title.isEmpty ? "Terminal" : title)
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        guard let directory, let url = URL(string: directory) else { return }
        let path = url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        setTerminalTitle(path.isEmpty ? "Terminal" : path)
    }

    /// `exit` puts the drop-down away; the next Terminal tab starts a fresh shell.
    func processTerminated(source: TerminalView, exitCode: Int32?) {
        isShellRunning = false
        DispatchQueue.main.async { [weak self] in
            self?.hide()
            self?.terminal?.getTerminal().resetToInitialState()
        }
    }
}
