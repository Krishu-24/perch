//
//  ClaudeFormatting.swift
//  boringNotch
//
//  Short time strings for the Claude tab, sized for the notch.
//

import Foundation

enum ClaudeFormatting {
    /// "38m", "2h 13m", "4d 2h": the two largest units, rounded down; "<1m" under a minute.
    static func shortDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(max(interval, 0) / 60)
        if minutes < 1 { return "<1m" }
        let days = minutes / (24 * 60)
        let hours = (minutes % (24 * 60)) / 60
        let mins = minutes % 60
        if days > 0 { return hours > 0 ? "\(days)d \(hours)h" : "\(days)d" }
        if hours > 0 { return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h" }
        return "\(mins)m"
    }

    /// "Resets in 2h 13m", or "Resets soon" once the time has passed.
    static func resetText(_ date: Date, now: Date = Date()) -> String {
        date > now ? "Resets in \(shortDuration(date.timeIntervalSince(now)))" : "Resets soon"
    }

    /// "now" under a minute, otherwise "4m ago", "2h ago".
    static func ageText(_ date: Date, now: Date = Date()) -> String {
        let interval = now.timeIntervalSince(date)
        return interval < 60 ? "now" : "\(shortDuration(interval).split(separator: " ")[0]) ago"
    }
}
