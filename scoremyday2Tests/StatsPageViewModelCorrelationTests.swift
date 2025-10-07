import XCTest
@testable import scoremyday2

final class StatsPageViewModelCorrelationTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        StatsPageViewModel.correlationLogHandler = nil
    }

    func testCorrelationInsightRequiresMinimumSamples() {
        let viewModel = StatsPageViewModel()
        let deed = makePositiveDeed(name: "Run")
        let dayStarts = viewModel.testDaySequence(forDays: 60)
        let overlap = Array(dayStarts.prefix(10))

        var dailyNet: [Date: Double] = [:]
        var positive: [Date: Double] = [:]
        for (index, day) in overlap.enumerated() {
            dailyNet[day] = Double(index + 1)
            positive[day] = Double(index + 1)
        }

        viewModel.testInjectCorrelationData(
            deeds: [deed.id: deed],
            dailyNet: dailyNet,
            positivePoints: [deed.id: positive]
        )

        var logs: [(String, Double, Int)] = []
        StatsPageViewModel.correlationLogHandler = { deedName, r, samples in
            logs.append((deedName, r, samples))
        }

        let insight = viewModel.testCorrelationInsight()

        XCTAssertNil(insight)
        XCTAssertTrue(logs.isEmpty)
    }

    func testCorrelationInsightRequiresThreshold() {
        let viewModel = StatsPageViewModel()
        let deed = makePositiveDeed(name: "Read")
        let dayStarts = viewModel.testDaySequence(forDays: 60)
        let overlap = Array(dayStarts.prefix(20))

        var dailyNet: [Date: Double] = [:]
        var positive: [Date: Double] = [:]
        for (index, day) in overlap.enumerated() {
            dailyNet[day] = Double(index + 1)
            positive[day] = index.isMultiple(of: 2) ? 1 : 0
        }

        viewModel.testInjectCorrelationData(
            deeds: [deed.id: deed],
            dailyNet: dailyNet,
            positivePoints: [deed.id: positive]
        )

        var logs: [(String, Double, Int)] = []
        StatsPageViewModel.correlationLogHandler = { deedName, r, samples in
            logs.append((deedName, r, samples))
        }

        let insight = viewModel.testCorrelationInsight()

        XCTAssertNil(insight)
        XCTAssertTrue(logs.isEmpty)
    }

    func testCorrelationInsightEmitsWhenThresholdMet() {
        let viewModel = StatsPageViewModel()
        let deed = makePositiveDeed(name: "Exercise")
        let dayStarts = viewModel.testDaySequence(forDays: 60)
        let overlap = Array(dayStarts.prefix(25))

        var dailyNet: [Date: Double] = [:]
        var positive: [Date: Double] = [:]
        for (index, day) in overlap.enumerated() {
            let value = Double(index + 1)
            dailyNet[day] = value
            positive[day] = value * 2
        }

        viewModel.testInjectCorrelationData(
            deeds: [deed.id: deed],
            dailyNet: dailyNet,
            positivePoints: [deed.id: positive]
        )

        var logs: [(String, Double, Int)] = []
        StatsPageViewModel.correlationLogHandler = { deedName, r, samples in
            logs.append((deedName, r, samples))
        }

        let insight = viewModel.testCorrelationInsight()

        XCTAssertNotNil(insight)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.0, deed.name)
        XCTAssertEqual(logs.first?.2, overlap.count)
        XCTAssertEqual(insight?.coefficient ?? 0, 1, accuracy: 0.0001)
        XCTAssertEqual(
            insight?.message,
            "You tend to score higher on days you \(deed.name.lowercased())"
        )
    }

    private func makePositiveDeed(name: String) -> DeedCard {
        DeedCard(
            name: name,
            emoji: "🏃‍♂️",
            colorHex: "FFFFFF",
            category: "Health",
            polarity: .positive,
            unitType: .count,
            unitLabel: "times",
            pointsPerUnit: 1,
            dailyCap: nil,
            isPrivate: false,
            showOnStats: true
        )
    }
}
