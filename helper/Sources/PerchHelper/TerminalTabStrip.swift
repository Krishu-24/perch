//
//  TerminalTabStrip.swift
//  PerchHelper
//
//  The notch's tabs, along the terminal's top strip just left of the notch, where the
//  open notch shows them. The terminal covers the notch, so without these the other
//  tabs would be out of reach until you put the terminal away. Resting on one (or
//  clicking it) puts the terminal away and opens the notch on that tab.
//
//  Hovering works like the notch's own tabs, with TabAim's safe triangle, plus one rule
//  of its own: the strip ignores the pointer until it has moved, since the terminal
//  drops while the pointer is resting right here on the notch's Terminal tab.
//

import AppKit
import PerchDevCore

final class TerminalTabStrip: NSView {
    struct Tab {
        /// What Perch calls the tab.
        let name: String
        let symbol: String
        let label: String
    }

    /// The notch's tabs, in its order.
    static let tabs = [
        Tab(name: "home", symbol: "house.fill", label: "Home"),
        Tab(name: "terminal", symbol: "apple.terminal.fill", label: "Terminal"),
        Tab(name: "limits", symbol: "gauge.with.dots.needle.33percent", label: "Limits"),
        Tab(name: "claude", symbol: "sparkles", label: "Claude"),
        Tab(name: "dev", symbol: "chart.bar.xaxis", label: "Dev"),
    ]
    static let current = "terminal"
    static let tabWidth: CGFloat = 40
    static let tabHeight: CGFloat = 24
    static var width: CGFloat { tabWidth * CGFloat(tabs.count) }

    /// How far the pointer has to move before the strip takes hovering seriously.
    private static let armDistance: CGFloat = 8
    /// A little slower than the notch: you're mostly here to type.
    private static let minimumDelay: TimeInterval = 0.15

    /// Called with a tab's name when one is picked.
    var onSelect: ((String) -> Void)?

    private var buttons: [NSButton] = []
    private var hovered: Int?
    private var pending: (index: Int, timer: Timer)?
    private var aim = TabAim(contentTop: 0, contentMinX: 0, contentMaxX: 0)
    private var armedFrom: NSPoint?
    private var isArmed = false
    private var trackingArea: NSTrackingArea?

    init(frame: NSRect, contentMinX: CGFloat, contentMaxX: CGFloat) {
        super.init(frame: frame)
        // In the strip's flipped coordinates the terminal starts just below its bottom edge.
        aim = TabAim(contentTop: frame.height + 4, contentMinX: contentMinX, contentMaxX: contentMaxX)

        for (index, tab) in Self.tabs.enumerated() {
            let image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.label)?
                .withSymbolConfiguration(.init(pointSize: 12, weight: .semibold))
            let button = NSButton(image: image ?? NSImage(), target: self, action: #selector(clicked(_:)))
            button.isBordered = false
            button.bezelStyle = .regularSquare
            button.imagePosition = .imageOnly
            button.tag = index
            button.toolTip = tab.label
            button.setAccessibilityLabel(tab.label)
            button.wantsLayer = true
            button.layer?.cornerRadius = Self.tabHeight / 2
            button.frame = NSRect(x: CGFloat(index) * Self.tabWidth, y: (frame.height - Self.tabHeight) / 2,
                                  width: Self.tabWidth, height: Self.tabHeight)
            addSubview(button)
            buttons.append(button)
        }
        restyle()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Called each time the terminal drops: forget the last hover and wait for the pointer to move.
    func arm() {
        cancelPending()
        hovered = nil
        aim.reset()
        isArmed = false
        armedFrom = NSEvent.mouseLocation
        restyle()
    }

    // MARK: - Tracking

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        if !isArmed {
            let start = armedFrom ?? NSEvent.mouseLocation
            let now = NSEvent.mouseLocation
            guard hypot(now.x - start.x, now.y - start.y) >= Self.armDistance else { return }
            isArmed = true
        }
        let local = convert(event.locationInWindow, from: nil)
        hover(at: CGPoint(x: local.x, y: bounds.height - local.y))
    }

    override func mouseEntered(with event: NSEvent) {
        mouseMoved(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        hovered = nil
        aim.reset()
        cancelPending()
        restyle()
    }

    /// `point` is flipped, y growing downward, as TabAim expects.
    private func hover(at point: CGPoint) {
        let headingForContent = aim.move(to: point)
        let index = buttons.firstIndex { $0.frame.minX <= point.x && point.x < $0.frame.maxX }
        if index != hovered {
            hovered = index
            restyle()
        }
        guard let index, Self.tabs[index].name != Self.current else {
            cancelPending()
            return
        }
        if pending?.index == index && !headingForContent { return }

        cancelPending()
        let delay = max(Self.minimumDelay, TabAim.delay(isAction: false, headingForContent: headingForContent))
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self, self.hovered == index else { return }
            self.pending = nil
            self.select(index)
        }
        pending = (index, timer)
    }

    private func cancelPending() {
        pending?.timer.invalidate()
        pending = nil
    }

    @objc private func clicked(_ sender: NSButton) {
        select(sender.tag)
    }

    private func select(_ index: Int) {
        cancelPending()
        let name = Self.tabs[index].name
        guard name != Self.current else { return }
        onSelect?(name)
    }

    /// The terminal's tab sits in a capsule, as the notch's selected tab does; the hovered one brightens.
    private func restyle() {
        for (index, button) in buttons.enumerated() {
            let isCurrent = Self.tabs[index].name == Self.current
            button.contentTintColor = isCurrent || hovered == index ? .white : NSColor(white: 1, alpha: 0.45)
            button.layer?.backgroundColor = isCurrent ? NSColor(white: 1, alpha: 0.14).cgColor : NSColor.clear.cgColor
        }
    }
}
