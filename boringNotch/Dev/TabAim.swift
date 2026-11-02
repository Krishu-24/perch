//
//  TabAim.swift
//  Perch
//
//  Hovering a notch tab switches to it, without switching the tabs you only pass over.
//  It's the menu-aim ("safe triangle") rule turned on its side: the tabs sit in a row
//  above the content, so while the pointer heads down toward the content, a tab it
//  crosses waits until the pointer stops on it.
//
//  The triangle runs from where the pointer was a few moves ago to the top corners of
//  the content. A pointer inside it is aiming at the content; one outside it is moving
//  along the row and means the tab it's on.
//
//  Shared with Perch Helper, whose terminal shows the same tabs along its top strip.
//

import CoreGraphics
import Foundation

public struct TabAim {
    /// How long the pointer rests on a tab before it switches.
    public static let settleDelay: TimeInterval = 0.08
    /// The same while heading for the content: long enough to cross a tab, short enough to pick one by stopping.
    public static let aimDelay: TimeInterval = 0.3
    /// A tab that does something, like dropping the terminal, wants a deliberate pause.
    public static let actionDelay: TimeInterval = 0.4

    /// The content's top edge, in the tab row's coordinates (y grows downward): the triangle's base.
    public var contentTop: CGFloat
    public var contentMinX: CGFloat
    public var contentMaxX: CGFloat

    /// The last few pointer locations, oldest first. The oldest is the triangle's apex, which
    /// smooths out the jitter of single moves.
    public private(set) var trail: [CGPoint] = []
    private static let trailLength = 3

    public init(contentTop: CGFloat, contentMinX: CGFloat, contentMaxX: CGFloat) {
        self.contentTop = contentTop
        self.contentMinX = contentMinX
        self.contentMaxX = contentMaxX
    }

    public mutating func reset() {
        trail = []
    }

    /// Records where the pointer is and says whether it's heading for the content.
    public mutating func move(to point: CGPoint) -> Bool {
        let apex = trail.first
        trail.append(point)
        if trail.count > Self.trailLength { trail.removeFirst() }
        guard let apex, apex != point, point.y < contentTop else { return false }
        return Self.triangle(apex, CGPoint(x: contentMinX, y: contentTop), CGPoint(x: contentMaxX, y: contentTop),
                             contains: point)
    }

    /// How long the pointer has to stay on a tab before it switches.
    public static func delay(isAction: Bool, headingForContent: Bool) -> TimeInterval {
        if isAction { return actionDelay }
        return headingForContent ? aimDelay : settleDelay
    }

    /// Whether `p` is strictly inside the triangle `abc`, whichever way round it's wound.
    public static func triangle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, contains p: CGPoint) -> Bool {
        func cross(_ o: CGPoint, _ u: CGPoint, _ v: CGPoint) -> CGFloat {
            (u.x - o.x) * (v.y - o.y) - (u.y - o.y) * (v.x - o.x)
        }
        let d1 = cross(a, b, p), d2 = cross(b, c, p), d3 = cross(c, a, p)
        return (d1 > 0 && d2 > 0 && d3 > 0) || (d1 < 0 && d2 < 0 && d3 < 0)
    }
}
