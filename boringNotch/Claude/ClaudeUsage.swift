// Ported from Open Island (github.com/Octane0411/open-vibe-island),
// Sources/OpenIslandCore/ClaudeUsage.swift, licensed under GPL-3.0.
// Changed: reads the perch-bridge mod's limits.json instead of the status-line
// cache, and dropped the public API and the multi-file fallback.

import Foundation

struct ClaudeUsageWindow: Equatable {
    var usedPercentage: Double
    var resetsAt: Date?

    var roundedUsedPercentage: Int {
        Int(usedPercentage.rounded())
    }
}

struct ClaudeUsageSnapshot: Equatable {
    var fiveHour: ClaudeUsageWindow?
    var sevenDay: ClaudeUsageWindow?
    var cachedAt: Date?

    var isEmpty: Bool {
        fiveHour == nil && sevenDay == nil
    }
}

enum ClaudeUsageLoader {
    static func load(from url: URL) -> ClaudeUsageSnapshot? {
        guard let data = try? Data(contentsOf: url),
              let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }

        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let snapshot = ClaudeUsageSnapshot(
            fiveHour: usageWindow(for: "five_hour", in: payload),
            sevenDay: usageWindow(for: "seven_day", in: payload),
            cachedAt: attributes?[.modificationDate] as? Date
        )

        return snapshot.isEmpty ? nil : snapshot
    }

    private static func usageWindow(for key: String, in payload: [String: Any]) -> ClaudeUsageWindow? {
        guard let window = payload[key] as? [String: Any],
              let rawPercentage = number(from: window["used_percentage"]) ?? number(from: window["utilization"]) else {
            return nil
        }

        return ClaudeUsageWindow(
            usedPercentage: rawPercentage,
            resetsAt: date(from: window["resets_at"])
        )
    }

    private static func number(from value: Any?) -> Double? {
        switch value {
        case let value as NSNumber:
            value.doubleValue
        case let value as String:
            Double(value)
        default:
            nil
        }
    }

    private static func date(from value: Any?) -> Date? {
        switch value {
        case let value as NSNumber:
            return Date(timeIntervalSince1970: value.doubleValue)
        case let value as String:
            if let seconds = Double(value) {
                return Date(timeIntervalSince1970: seconds)
            }
            let formatterWithFractionalSeconds = ISO8601DateFormatter()
            formatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatterWithFractionalSeconds.date(from: value) {
                return date
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: value)
        default:
            return nil
        }
    }
}
