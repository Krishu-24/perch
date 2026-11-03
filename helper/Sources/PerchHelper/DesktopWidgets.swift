//
//  DesktopWidgets.swift
//  PerchHelper
//
//  Puts the widget board on the desktop: a borderless window at desktop level, so
//  every app window covers it, clickable without taking focus. By default it only
//  appears while you're on the desktop (Finder in front, as after clicking the
//  wallpaper) and fades away when you go back to an app.
//

import AppKit
import PerchDevCore
import PerchWidgets
import SwiftUI

/// Takes the first click, so a widget responds even though the helper isn't the active app.
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class DesktopWidgets {
    /// Room around the cards for their shadows.
    private static let margin: CGFloat = 20
    private static let finderID = "com.apple.finder"

    let model = WidgetModel()
    private var panel: NSPanel?
    private var settings: WidgetSettings?
    private var isShown = false
    private var observers: [NSObjectProtocol] = []

    init() {
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.place()
        })
        // Whether you're on the desktop changes with the frontmost app.
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.update(animated: true)
            })
        }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0); NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

    /// Shows, hides or moves the board to match Perch's settings.
    func apply(_ newSettings: WidgetSettings) {
        guard newSettings != settings else { return }
        let moved = newSettings.position != settings?.position
        settings = newSettings
        if moved { place() }
        update(animated: false)
    }

    /// Whether the board belongs on screen right now.
    private var shouldShow: Bool {
        switch settings?.visibility ?? .onDesktop {
        case .always: return true
        case .off: return false
        case .onDesktop:
            // Finder in front means the desktop: clicking the wallpaper, or nothing else open.
            // Clicking a widget doesn't change it, since the board never takes focus.
            return NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Self.finderID
        }
    }

    private func update(animated: Bool) {
        let show = shouldShow
        guard show != isShown else { return }
        isShown = show
        if show {
            if panel == nil { build(); place() }
            guard let panel else { return }
            panel.alphaValue = animated ? 0 : 1
            panel.orderFront(nil)
            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    panel.animator().alphaValue = 1
                }
            }
        } else {
            guard let panel else { return }
            guard animated else { panel.orderOut(nil); return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                panel.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                // Ordered out, not just transparent, so it can't catch clicks meant for the desktop.
                if self?.isShown == false { panel.orderOut(nil) }
            })
        }
    }

    private func build() {
        let size = NSSize(width: WidgetLayout.boardSize.width + Self.margin * 2,
                          height: WidgetLayout.boardSize.height + Self.margin * 2)
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        // Just above the desktop icons, below every normal window.
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = FirstClickHostingView(rootView: WidgetBoard(model: model).padding(Self.margin))
        self.panel = panel
    }

    /// Puts the board in the chosen corner of the main screen, clear of the menu bar and Dock.
    private func place() {
        guard let panel, let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
        let area = screen.visibleFrame
        let size = panel.frame.size
        let position = settings?.position ?? .topRight
        let x = (position == .topLeft || position == .bottomLeft) ? area.minX : area.maxX - size.width
        let y = (position == .topLeft || position == .topRight) ? area.maxY - size.height : area.minY
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
