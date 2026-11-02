//
//  DesktopWidgets.swift
//  PerchHelper
//
//  Puts the widget board on the desktop: a borderless window at desktop level, so
//  every app window covers it, on every Space, and clickable without taking focus.
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

    let model = WidgetModel()
    private var panel: NSPanel?
    private var settings: WidgetSettings?
    private var screenObserver: NSObjectProtocol?

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.place()
        }
    }

    /// Shows, hides or moves the board to match Perch's settings.
    func apply(_ newSettings: WidgetSettings) {
        guard newSettings != settings else { return }
        settings = newSettings
        if newSettings.showDesktopWidgets {
            if panel == nil { build() }
            place()
            panel?.orderFront(nil)
        } else {
            panel?.orderOut(nil)
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
