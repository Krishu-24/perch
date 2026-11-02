//
//  WidgetData.swift
//  PerchDevCore
//
//  What the desktop widgets show besides dev.json: Claude's limits and sessions from
//  the perch-bridge mod's files.
//

import Foundation

/// Claude Code's side, as the widgets need it.
public struct ClaudeStatus: Equatable {
    public var fiveHour: UsageWindow?
    public var week: UsageWindow?
    public var updatedAt: Date?
    public var working: Int
    public var needsYou: Int

    public init(fiveHour: UsageWindow? = nil, week: UsageWindow? = nil, updatedAt: Date? = nil, working: Int = 0, needsYou: Int = 0) {
        self.fiveHour = fiveHour
        self.week = week
        self.updatedAt = updatedAt
        self.working = working
        self.needsYou = needsYou
    }

    /// Reads `limits.json` and `sessions/*.json` from Perch's folder.
    public static func load(from folder: URL, now: Date = Date()) -> ClaudeStatus {
        var status = ClaudeStatus()
        let limitsFile = folder.appendingPathComponent("limits.json")
        if let data = try? Data(contentsOf: limitsFile),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            status.fiveHour = window(object["five_hour"])
            status.week = window(object["seven_day"])
            status.updatedAt = (try? FileManager.default.attributesOfItem(atPath: limitsFile.path))?[.modificationDate] as? Date
        }
        let sessions = folder.appendingPathComponent("sessions", isDirectory: true)
        for file in (try? FileManager.default.contentsOfDirectory(at: sessions, includingPropertiesForKeys: nil)) ?? [] {
            guard file.pathExtension == "json", let data = try? Data(contentsOf: file),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let updated = (object["updatedAt"] as? NSNumber)?.doubleValue,
                  now.timeIntervalSince1970 - updated / 1000 < 2 * 3600 else { continue }
            switch object["status"] as? String {
            case "working": status.working += 1
            case "needs_you": status.needsYou += 1
            default: break
            }
        }
        return status
    }

    private static func window(_ value: Any?) -> UsageWindow? {
        guard let object = value as? [String: Any],
              let used = (object["used_percentage"] as? NSNumber)?.doubleValue else { return nil }
        let resets: Date?
        if let text = object["resets_at"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            resets = formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text)
        } else {
            resets = (object["resets_at"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
        }
        return UsageWindow(usedPercent: used, resetsAt: resets)
    }
}
