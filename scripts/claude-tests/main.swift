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

section("closed notch: Claude or what's playing") {
    let claude = ClaudeSessionStore.claudeAppID
    let safari = "com.apple.Safari"
    func show(needsYou: Int = 0, working: Int = 0, finished: Int = 0, media: Bool, in app: String?) -> Bool {
        ClaudeLiveActivity.shouldShow(needsYou: needsYou, working: working, justFinished: finished,
                                      isMediaActive: media, frontmostAppID: app, mediaAppID: media ? safari : nil)
    }
    check(show(working: 1, media: true, in: safari), true, "watching Prime in Safari while Claude works: show Claude")
    check(show(working: 1, media: true, in: claude), false, "in Claude while Prime plays: show Prime")
    check(show(finished: 1, media: true, in: safari), true, "Claude finished while you watch: show the check")
    check(show(working: 1, media: true, in: "com.microsoft.VSCode"), false, "elsewhere, plain working leaves the media")
    check(show(finished: 1, media: true, in: "com.microsoft.VSCode"), true, "elsewhere, a finished session shows")
    check(show(needsYou: 1, media: true, in: "com.microsoft.VSCode"), true, "needs you wins over media")
    check(show(needsYou: 1, media: true, in: claude), false, "unless you're already in Claude")
    check(show(working: 1, media: false, in: claude), true, "nothing playing: Claude shows anywhere")
    check(show(media: true, in: safari), false, "no Claude activity: nothing to show")
}

section("justFinished") {
    func session(_ id: String, _ status: String, finishedAgo: TimeInterval) throws -> ClaudeSession {
        let json = #"{"sessionId":"\#(id)","cwd":"/x","status":"\#(status)","prompt":"p","updatedAt":\#((now.timeIntervalSince1970 - finishedAgo) * 1000)}"#
        return try JSONDecoder().decode(ClaudeSession.self, from: Data(json.utf8))
    }
    let sessions = [try session("a", "done", finishedAgo: 60), try session("b", "done", finishedAgo: 10 * 60),
                    try session("c", "working", finishedAgo: 30), try session("d", "done", finishedAgo: 200)]
    check(ClaudeSessionStore.justFinished(sessions, since: .distantPast, now: now), 2, "done within the last five minutes")
    check(ClaudeSessionStore.justFinished(sessions, since: now.addingTimeInterval(-120), now: now), 1,
          "ones that finished before you last opened Claude are seen")
}

section("tab aim: the safe triangle") {
    let a = CGPoint(x: 0, y: 0), b = CGPoint(x: -10, y: 10), c = CGPoint(x: 10, y: 10)
    check(TabAim.triangle(a, b, c, contains: CGPoint(x: 0, y: 5)), true, "inside")
    check(TabAim.triangle(a, c, b, contains: CGPoint(x: 0, y: 5)), true, "either winding")
    check(TabAim.triangle(a, b, c, contains: CGPoint(x: 8, y: 2)), false, "outside, beside the apex")
    check(TabAim.triangle(a, b, c, contains: CGPoint(x: 5, y: 0)), false, "level with the apex is outside")

    // Tabs in a 26-point row; the content starts at y = 34 and spans x = -8 to 580.
    var aim = TabAim(contentTop: 34, contentMinX: -8, contentMaxX: 580)
    check(aim.move(to: CGPoint(x: 100, y: 10)), false, "the first location has nothing to compare with")
    check(aim.move(to: CGPoint(x: 101, y: 14)), true, "moving down is heading for the content")
    check(aim.move(to: CGPoint(x: 103, y: 20)), true, "and still is")

    aim.reset()
    _ = aim.move(to: CGPoint(x: 200, y: 12))
    check(aim.move(to: CGPoint(x: 170, y: 12)), false, "moving along the row means the tab you're on")
    check(aim.move(to: CGPoint(x: 140, y: 11)), false, "moving along the row and up a little, too")

    aim.reset()
    _ = aim.move(to: CGPoint(x: 100, y: 20))
    check(aim.move(to: CGPoint(x: 100, y: 12)), false, "moving up, away from the content")

    aim.reset()
    _ = aim.move(to: CGPoint(x: 100, y: 10))
    check(aim.move(to: CGPoint(x: 100, y: 40)), false, "past the row's edge is in the content, not aiming")

    aim.reset()
    for y in [7, 10, 13, 16] as [CGFloat] { _ = aim.move(to: CGPoint(x: 100, y: y)) }
    check(aim.trail.count, 3, "keeps only the last few locations")
    check(aim.trail.first, CGPoint(x: 100, y: 10), "the apex is the oldest of them")

    check(TabAim.delay(isAction: false, headingForContent: false), TabAim.settleDelay, "a tab you stop on switches quickly")
    check(TabAim.delay(isAction: false, headingForContent: true), TabAim.aimDelay, "a tab you cross on the way down waits")
    check(TabAim.delay(isAction: true, headingForContent: false), TabAim.actionDelay, "the terminal wants a real pause")
    check(TabAim.aimDelay > TabAim.settleDelay && TabAim.actionDelay > TabAim.settleDelay, true, "the waits are in order")
}

print(failures == 0 ? "PASS: \(checks) checks" : "\(failures) of \(checks) checks failed")
exit(failures == 0 ? 0 : 1)
