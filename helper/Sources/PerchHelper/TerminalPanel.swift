//
//  TerminalPanel.swift
//  PerchHelper
//
//  The drop-down that comes out of the notch: one panel with two tabs, Terminal and
//  Widgets, chosen in the strip beside the notch. Both stay alive while you switch,
//  and the shell keeps running while the panel is hidden, so a toggle brings back
//  exactly where you were.
//

import AppKit
import PerchDevCore
import PerchWidgets
import SwiftTerm
import SwiftUI

/// A borderless panel that can still take the keyboard.
final class DropdownPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

enum DropdownTab: String, CaseIterable {
    case terminal, widgets

    var title: String { self == .terminal ? "Terminal" : "Widgets" }
    var icon: String { self == .terminal ? "apple.terminal.fill" : "square.grid.2x2.fill" }
}

/// What the strip shows: the selected tab, and the shell's folder for the terminal.
final class DropdownState: ObservableObject {
    @Published var tab: DropdownTab = .terminal
    @Published var title = "~"
}

/// The tabs, drawn in the strip to the left of the notch.
struct DropdownStrip: View {
    @ObservedObject var state: DropdownState
    let select: (DropdownTab) -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                ForEach(DropdownTab.allCases, id: \.self) { tab in
                    Button { select(tab) } label: {
                        Label(tab.title, systemImage: tab.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(state.tab == tab ? .white : .white.opacity(0.45))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(state.tab == tab ? 0.14 : 0)))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            if state.tab == .terminal {
                Text(state.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
    }
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

/// Takes the first click, so a tab or widget responds straight away.
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class DropdownController: NSObject, NSWindowDelegate, LocalProcessTerminalViewDelegate {
    private static let accent = NSColor(red: 0.85, green: 0.47, blue: 0.34, alpha: 1)  // Claude orange
    /// Space around the content below the strip.
    private static let inset = NSEdgeInsets(top: 8, left: 16, bottom: 16, right: 16)

    let widgets: WidgetModel
    private let state = DropdownState()
    private var panel: DropdownPanel?
    private var terminal: LocalProcessTerminalView?
    private var widgetView: NSView?
    private var previousApp: NSRunningApplication?
    private var isShellRunning = false
    private var startDirectory: String?

    var isVisible: Bool { panel?.isVisible == true }

    init(widgets: WidgetModel) {
        self.widgets = widgets
    }

    /// Control-`: shows the drop-down on the tab you used last, or hides it.
    func toggle() {
        isVisible ? hide() : show(state.tab)
    }

    /// Shows the drop-down on `tab`; if it's already showing that tab, hides it.
    func toggle(_ tab: DropdownTab) {
        if isVisible && state.tab == tab { hide() } else { show(tab) }
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
        let screen = Self.notchScreen()
        if panel == nil || panel?.screen != screen { build(on: screen) }
        guard let panel else { return }
        select(tab)
        guard !panel.isVisible else { return }

        let frame = Self.frame(on: screen)
        previousApp = NSWorkspace.shared.frontmostApplication.flatMap {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier ? nil : $0
        }

        // Drop down out of the notch: start a little higher and clear, then settle.
        panel.setFrame(frame.offsetBy(dx: 0, dy: 24), display: false)
        panel.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        if tab == .terminal, let terminal { panel.makeFirstResponder(terminal) }
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

    /// Switches tabs; the other one stays as it was.
    private func select(_ tab: DropdownTab) {
        state.tab = tab
        terminal?.isHidden = tab != .terminal
        widgetView?.isHidden = tab != .widgets
        if tab == .terminal {
            if !isShellRunning { startShell() }
            if let terminal { panel?.makeFirstResponder(terminal) }
        } else {
            panel?.makeFirstResponder(nil)
        }
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

    /// Width of the notch itself, so the tabs stay clear of it.
    private static func notchWidth(of screen: NSScreen) -> CGFloat {
        guard let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { return 0 }
        return max(0, screen.frame.width - left.width - right.width)
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
        let notch = Self.notchWidth(of: screen)

        let panel = DropdownPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        // Above Perch's notch panel (main menu + 3), so the notch never opens on top of it.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 4)
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
        content.layer?.cornerRadius = 24
        content.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        content.layer?.masksToBounds = true
        panel.contentView = content

        // The strip beside the notch: tabs on the left, the shortcut on the right.
        let side = notch > 0 ? (frame.width - notch) / 2 - 12 : frame.width / 2 - 20
        let tabs = FirstClickHostingView(rootView: DropdownStrip(state: state) { [weak self] tab in self?.select(tab) })
        tabs.frame = NSRect(x: 16, y: frame.height - strip, width: side - 16, height: strip)
        tabs.autoresizingMask = [.minYMargin]
        content.addSubview(tabs)

        let hint = NSTextField(labelWithString: "⌃` to hide")
        hint.font = .systemFont(ofSize: 11, weight: .medium)
        hint.textColor = NSColor(white: 1, alpha: 0.3)
        hint.alignment = .right
        hint.frame = NSRect(x: frame.width - side, y: frame.height - strip + (strip - 16) / 2, width: side - 20, height: 16)
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
        select(state.tab)
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
        let directory = startDirectory ?? NSHomeDirectory()
        terminal.startProcess(executable: shell, args: [], environment: environment,
                              execName: "-" + URL(fileURLWithPath: shell).lastPathComponent,
                              currentDirectory: directory)
        state.title = directory.replacingOccurrences(of: NSHomeDirectory(), with: "~")
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
        if !title.isEmpty { state.title = title }
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        guard let directory, let url = URL(string: directory) else { return }
        let path = url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        if !path.isEmpty { state.title = path }
    }

    /// `exit` ends the shell and hides the drop-down; the next Terminal tab starts a fresh one.
    func processTerminated(source: TerminalView, exitCode: Int32?) {
        isShellRunning = false
        DispatchQueue.main.async { [weak self] in
            self?.hide()
            self?.terminal?.getTerminal().resetToInitialState()
        }
    }
}
