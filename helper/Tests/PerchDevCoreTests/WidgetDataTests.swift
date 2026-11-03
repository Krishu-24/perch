import XCTest
@testable import PerchDevCore

final class WidgetDataTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("perch-widgets-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("sessions"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func write(_ text: String, to name: String) throws {
        try text.write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    func testClaudeStatusReadsLimitsAndCountsLiveSessions() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try write(#"{"five_hour":{"used_percentage":34,"resets_at":"2026-11-02T23:30:00.000Z"},"seven_day":{"used_percentage":22,"resets_at":"2026-11-08T09:00:00.000Z"}}"#,
                  to: "limits.json")
        let ms = now.timeIntervalSince1970 * 1000
        try write(#"{"status":"working","updatedAt":\#(ms - 5000)}"#, to: "sessions/a.json")
        try write(#"{"status":"needs_you","updatedAt":\#(ms - 60000)}"#, to: "sessions/b.json")
        try write(#"{"status":"working","updatedAt":\#(ms - 3 * 3600 * 1000)}"#, to: "sessions/stale.json")
        try write(#"{"status":"done","updatedAt":\#(ms)}"#, to: "sessions/c.json")

        let status = ClaudeStatus.load(from: folder, now: now)
        XCTAssertEqual(status.fiveHour?.usedPercent, 34)
        XCTAssertEqual(status.week?.usedPercent, 22)
        XCTAssertEqual(status.fiveHour?.resetsAt, ISO8601DateFormatter().date(from: "2026-11-02T23:30:00Z"))
        XCTAssertEqual(status.working, 1, "a session silent for hours doesn't count")
        XCTAssertEqual(status.needsYou, 1)
        XCTAssertNotNil(status.updatedAt)
    }

    func testClaudeStatusWithNothingWritten() {
        let status = ClaudeStatus.load(from: folder.appendingPathComponent("missing"))
        XCTAssertNil(status.fiveHour)
        XCTAssertEqual(status.working, 0)
    }

    func testWidgetSettingsDefaultToHiddenTopRight() throws {
        XCTAssertEqual(WidgetSettings.load(from: folder), WidgetSettings(showDesktopWidgets: false, position: .topRight))
        try write(#"{"showDesktopWidgets":false,"position":"bottomLeft"}"#, to: WidgetSettings.fileName)
        XCTAssertEqual(WidgetSettings.load(from: folder), WidgetSettings(showDesktopWidgets: false, position: .bottomLeft))
        try write("not json", to: WidgetSettings.fileName)
        XCTAssertEqual(WidgetSettings.load(from: folder), WidgetSettings(), "a broken file falls back to the defaults")
    }
}
