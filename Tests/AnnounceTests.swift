import XCTest
@testable import PhysicsGame

/// Announce — the VoiceOver announcement throat. The real poster talks to
/// AccessibilityNotification (untestable headless); the seam lets us pin the
/// routing: callers' strings and priorities arrive intact.
@MainActor
final class AnnounceTests: XCTestCase {

    func testPostRoutesMessageAndPriorityThroughPoster() {
        var captured: [(message: String, priority: Announce.Priority)] = []
        let original = Announce.poster
        defer { Announce.poster = original }
        Announce.poster = { message, priority in captured.append((message, priority)) }

        Announce.post("Nailed it. Read it right.")
        Announce.post("Right call, it went in.", priority: .queued)

        XCTAssertEqual(captured.count, 2)
        XCTAssertEqual(captured[0].message, "Nailed it. Read it right.")
        XCTAssertEqual(captured[0].priority, .high, "default priority is high — verdicts interrupt")
        XCTAssertEqual(captured[1].message, "Right call, it went in.")
        XCTAssertEqual(captured[1].priority, .queued)
    }
}
