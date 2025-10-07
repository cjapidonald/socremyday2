import XCTest
@testable import scoremyday2

final class FloatingDeltaQueueTests: XCTestCase {
    func testSpacingBetweenRapidEventsIsWithinLimit() {
        var queue = FloatingDeltaQueue(spacing: 0.08)
        let base = Date(timeIntervalSince1970: 0)
        let requestTimes = [0.0, 0.01, 0.02].map { base.addingTimeInterval($0) }

        var scheduled: [TimeInterval] = []
        for request in requestTimes {
            let delay = queue.nextDelay(now: request)
            scheduled.append(request.timeIntervalSince(base) + delay)
        }

        XCTAssertEqual(scheduled.count, 3)
        XCTAssertLessThanOrEqual(scheduled[1] - scheduled[0], 0.1, "Events should start within 100ms of one another")
        XCTAssertLessThanOrEqual(scheduled[2] - scheduled[1], 0.1, "Events should start within 100ms of one another")

        // After a longer pause the queue should reset and emit immediately.
        let later = base.addingTimeInterval(1.0)
        let finalDelay = queue.nextDelay(now: later)
        XCTAssertEqual(finalDelay, 0, accuracy: 0.0001)
    }
}
