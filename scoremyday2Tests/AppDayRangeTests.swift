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

final class StatsInsightTests: XCTestCase {
    func testBestImprovementSelectsLargestGain() {
        let comparisons = [
            CategoryComparison(category: "Focus", current: 12, previous: 6),
            CategoryComparison(category: "Health", current: 4, previous: 4),
            CategoryComparison(category: "Learning", current: 3, previous: 0)
        ]

        let result = StatsMath.bestImprovement(from: comparisons)

        XCTAssertEqual(result?.category, "Focus")
        XCTAssertEqual(result?.percent, 1, accuracy: 0.0001)
    }

    func testPearsonCorrelationDetectsPositiveRelationship() {
        let netScores: [Double] = [10, 15, 20, 25, 30]
        let deedPoints: [Double] = [1, 2, 3, 4, 5]

        let correlation = StatsMath.pearsonCorrelation(x: netScores, y: deedPoints)

        XCTAssertNotNil(correlation)
        XCTAssertGreaterThan(correlation ?? 0, 0.99)
    }

    func testPearsonCorrelationReturnsNilWithoutVariance() {
        let netScores: [Double] = [10, 10, 10]
        let deedPoints: [Double] = [1, 2, 3]

        XCTAssertNil(StatsMath.pearsonCorrelation(x: netScores, y: deedPoints))
    }
}

@MainActor
final class AppEnvironmentToastTests: XCTestCase {
    func testToastClearsAfterDuration() async throws {
        let environment = AppEnvironment(persistenceController: PersistenceController(inMemory: true))

        environment.showToast(message: "Loaded", duration: 0.05)

        XCTAssertEqual(environment.toast?.message, "Loaded")

        try await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertNil(environment.toast)
    }

    func testLatestToastReplacesPrevious() async throws {
        let environment = AppEnvironment(persistenceController: PersistenceController(inMemory: true))

        environment.showToast(message: "First", duration: 1)
        environment.showToast(message: "Second", duration: 1)

        XCTAssertEqual(environment.toast?.message, "Second")

        environment.hideToast()
        XCTAssertNil(environment.toast)
    }
}
