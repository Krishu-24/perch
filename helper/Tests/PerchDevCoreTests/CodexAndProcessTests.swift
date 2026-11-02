import XCTest
@testable import PerchDevCore

final class CodexUsageParserTests: XCTestCase {
    // Lines as Codex writes them in rollout-*.jsonl: a reading with every reply.
    let session = #"""
    {"timestamp":"2026-11-02T03:23:27.000Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":5.0,"window_minutes":300,"resets_at":1793587878},"secondary":{"used_percent":1.0,"window_minutes":10080,"resets_at":1793996458},"plan_type":"plus"}}}
    {"timestamp":"2026-11-02T03:30:00.000Z","type":"response_item","payload":{"type":"message"}}
    {"timestamp":"2026-11-02T03:40:00.000Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":9.0,"window_minutes":300,"resets_at":1793587878},"secondary":{"used_percent":2.0,"window_minutes":10080,"resets_at":1793996458},"plan_type":"plus"}}}
    {"timestamp":"2026-11-02T03:41:00.000Z","type":"event_msg","payload":{"type":"token_count","rate_limits":null}}
    """#

    func testNewestReadingWins() {
        let limits = CodexUsageParser.latest(in: session)
        XCTAssertEqual(limits?.plan, "plus")
        XCTAssertEqual(limits?.fiveHour?.usedPercent, 9)
        XCTAssertEqual(limits?.week?.usedPercent, 2)
        XCTAssertEqual(limits?.fiveHour?.resetsAt, Date(timeIntervalSince1970: 1_793_587_878))
        XCTAssertEqual(limits?.capturedAt, ISO8601DateFormatter().date(from: "2026-11-02T03:40:00Z"))
    }

    func testNoReading() {
        XCTAssertNil(CodexUsageParser.latest(in: #"{"type":"session_meta","payload":{}}"#))
        XCTAssertNil(CodexUsageParser.latest(in: ""))
    }
}

final class ProcessSummaryTests: XCTestCase {
    func testShortensCommandLines() {
        XCTAssertEqual(ProcessSummary.summarize("node /Users/me/site/node_modules/.bin/next dev"), "next dev")
        XCTAssertEqual(ProcessSummary.summarize("node /Users/me/docs/node_modules/.bin/vite --port 5173"), "vite --port 5173")
        XCTAssertEqual(ProcessSummary.summarize("/opt/homebrew/bin/python3.12 -m uvicorn main:app --reload"), "uvicorn main:app --reload")
        XCTAssertEqual(ProcessSummary.summarize("python3 -m http.server 8000"), "http.server 8000")
        XCTAssertEqual(ProcessSummary.summarize("/Users/me/go/bin/air"), "air")
    }
}
