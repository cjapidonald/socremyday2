import XCTest
@testable import scoremyday2

final class AppDayRangeTests: XCTestCase {
    func testAppDayRangeBeforeCutoffUsesPreviousDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let reference = calendar.date(from: DateComponents(year: 2024, month: 1, day: 10, hour: 2))!
        let range = appDayRange(for: reference, cutoffHour: 4, calendar: calendar)

        let expectedStart = calendar.date(from: DateComponents(year: 2024, month: 1, day: 9, hour: 4))!
        let expectedEnd = calendar.date(from: DateComponents(year: 2024, month: 1, day: 10, hour: 4))!

        XCTAssertEqual(range.start, expectedStart)
        XCTAssertEqual(range.end, expectedEnd)
    }

    func testAppDayRangeAfterCutoffUsesSameDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let reference = calendar.date(from: DateComponents(year: 2024, month: 1, day: 10, hour: 16))!
        let range = appDayRange(for: reference, cutoffHour: 4, calendar: calendar)

        let expectedStart = calendar.date(from: DateComponents(year: 2024, month: 1, day: 10, hour: 4))!
        let expectedEnd = calendar.date(from: DateComponents(year: 2024, month: 1, day: 11, hour: 4))!

        XCTAssertEqual(range.start, expectedStart)
        XCTAssertEqual(range.end, expectedEnd)
    }
}
