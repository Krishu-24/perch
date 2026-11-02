// Tests for the Claude tab's logic: time strings, the limits file, and which
// sessions the tab shows. Run scripts/claude-tests/run.sh.

import Foundation

var failures = 0
var checks = 0

func check<T: Equatable>(_ actual: T, _ expected: T, _ what: String, line: Int = #line) {
    checks += 1
    if actual != expected {
        failures += 1
        print("FAIL line \(line): \(what)\n  expected: \(expected)\n  actual:   \(actual)")
    }
}

func section(_ name: String, _ body: () throws -> Void) {
    do { try body() } catch {
        failures += 1
        print("FAIL \(name): threw \(error)")
    }
}

func temporaryFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("claude-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

let now = Date(timeIntervalSince1970: 1_800_000_000)

section("shortDuration") {
    check(ClaudeFormatting.shortDuration(30), "<1m", "under a minute")
    check(ClaudeFormatting.shortDuration(-5), "<1m", "negative clamps to zero")
    check(ClaudeFormatting.shortDuration(38 * 60 + 59), "38m", "minutes round down")
    check(ClaudeFormatting.shortDuration(2 * 3600), "2h", "whole hours drop the minutes")
    check(ClaudeFormatting.shortDuration(2 * 3600 + 13 * 60), "2h 13m", "hours and minutes")
    check(ClaudeFormatting.shortDuration(86400), "1d", "whole days drop the hours")
    check(ClaudeFormatting.shortDuration(4 * 86400 + 2 * 3600 + 59 * 60), "4d 2h", "days and hours, minutes dropped")
}

section("resetText and ageText") {
    check(ClaudeFormatting.resetText(now.addingTimeInterval(38 * 60), now: now), "Resets in 38m", "future reset")
    check(ClaudeFormatting.resetText(now.addingTimeInterval(-10), now: now), "Resets soon", "reset already passed")
    check(ClaudeFormatting.ageText(now.addingTimeInterval(-20), now: now), "now", "under a minute ago")
    check(ClaudeFormatting.ageText(now.addingTimeInterval(-4 * 60), now: now), "4m ago", "minutes ago")
    check(ClaudeFormatting.ageText(now.addingTimeInterval(-(2 * 3600 + 30 * 60)), now: now), "2h ago", "largest unit only")
}

section("ClaudeUsageLoader") {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("limits.json")

    check(ClaudeUsageLoader.load(from: file) == nil, true, "a missing file reads as no data")

    try #"{"five_hour":{"used_percentage":18.4,"resets_at":"2026-11-02T23:30:00.000Z"},"seven_day":{"utilization":"29","resets_at":1794128400},"updated_at":1}"#
        .write(to: file, atomically: true, encoding: .utf8)
    let usage = ClaudeUsageLoader.load(from: file)
    check(usage?.fiveHour?.roundedUsedPercentage, 18, "five-hour percent, rounded")
    check(usage?.fiveHour?.resetsAt, ISO8601DateFormatter().date(from: "2026-11-02T23:30:00Z"), "ISO reset time with fractional seconds")
    check(usage?.sevenDay?.usedPercentage, 29, "weekly percent from the utilization key, given as text")
    check(usage?.sevenDay?.resetsAt, Date(timeIntervalSince1970: 1_794_128_400), "reset time given in epoch seconds")
    check(usage?.cachedAt != nil, true, "the file's modification time is kept")

    try #"{"updated_at":1}"#.write(to: file, atomically: true, encoding: .utf8)
    check(ClaudeUsageLoader.load(from: file) == nil, true, "a file without windows reads as no data")

    try "not json".write(to: file, atomically: true, encoding: .utf8)
    check(ClaudeUsageLoader.load(from: file) == nil, true, "a broken file reads as no data")
}

section("readSessions") {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }

    func write(_ id: String, _ status: String, prompt: String? = "Do the thing", age: TimeInterval) throws {
        let promptField = prompt.map { #","prompt":"\#($0)""# } ?? ""
        let json = #"{"sessionId":"\#(id)","cwd":"/Users/me/Code/\#(id)","surface":"desktop","status":"\#(status)"\#(promptField),"updatedAt":\#((now.timeIntervalSince1970 - age) * 1000)}"#
        try json.write(to: folder.appendingPathComponent("\(id).json"), atomically: true, encoding: .utf8)
    }

    try write("done-recent", "done", age: 60)
    try write("working-old", "working", age: 30)
    try write("working-new", "working", age: 5)
    try write("waiting", "needs_you", age: 600)
    try write("prewarmed", "idle", prompt: nil, age: 10)
    try write("ended", "ended", age: 10)
    try write("done-stale", "done", age: 31 * 60)
    try write("working-stale", "working", age: 3 * 3600)
    try write("ancient", "done", age: 25 * 3600)
    try "{".write(to: folder.appendingPathComponent("broken.json"), atomically: true, encoding: .utf8)
    try "{}".write(to: folder.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

    let sessions = ClaudeSessionStore.readSessions(in: folder, now: now)
    check(sessions.map(\.id), ["waiting", "working-new", "working-old", "done-recent"],
          "needs-you first, then working newest first, then done; idle without a prompt, ended and stale ones hidden")
    check(sessions.first?.status, .needsYou, "needs_you decodes")
    check(sessions.first?.projectName, "waiting", "project name is the folder's name")
    check(FileManager.default.fileExists(atPath: folder.appendingPathComponent("ancient.json").path), false,
          "a file older than a day is deleted")
    check(FileManager.default.fileExists(atPath: folder.appendingPathComponent("done-stale.json").path), true,
          "a quiet session is hidden but its file kept")

    check(ClaudeSessionStore.readSessions(in: folder.appendingPathComponent("missing"), now: now).isEmpty, true,
          "a missing folder reads as no sessions")
}

print(failures == 0 ? "PASS: \(checks) checks" : "\(failures) of \(checks) checks failed")
exit(failures == 0 ? 0 : 1)
