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

final class DailyCapHintStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: DailyCapHintStore!
    private let suiteName = "DailyCapHintStoreTests"

    override func setUpWithError() throws {
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = DailyCapHintStore(userDefaults: defaults)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        store = nil
        defaults = nil
    }

    func testShowsHintWhenNoRecordExists() {
        let cardID = UUID()
        let reference = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertTrue(store.shouldShowHint(for: cardID, on: reference, cutoffHour: 4, calendar: testCalendar))
    }

    func testDoesNotShowHintTwiceInSameAppDay() {
        let cardID = UUID()
        let reference = Date(timeIntervalSince1970: 1_700_000_000)
        store.markHintShown(for: cardID, on: reference, cutoffHour: 4, calendar: testCalendar)

        let laterSameDay = reference.addingTimeInterval(3600)
        XCTAssertFalse(store.shouldShowHint(for: cardID, on: laterSameDay, cutoffHour: 4, calendar: testCalendar))
    }

    func testShowsHintAgainOnNewAppDay() {
        let cardID = UUID()
        let reference = Date(timeIntervalSince1970: 1_700_000_000)
        store.markHintShown(for: cardID, on: reference, cutoffHour: 4, calendar: testCalendar)

        let nextDay = testCalendar.date(byAdding: .day, value: 1, to: reference) ?? reference
        let middayNextDay = nextDay.addingTimeInterval(6 * 3600)

        XCTAssertTrue(store.shouldShowHint(for: cardID, on: middayNextDay, cutoffHour: 4, calendar: testCalendar))
    }

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        if let gmt = TimeZone(secondsFromGMT: 0) {
            calendar.timeZone = gmt
        }
        return calendar
    }
}
