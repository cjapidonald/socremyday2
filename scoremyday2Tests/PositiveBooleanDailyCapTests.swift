import CoreData
import XCTest
@testable import scoremyday2

final class PositiveBooleanDailyCapTests: XCTestCase {
    var persistence: PersistenceController!
    var entriesRepository: EntriesRepository!
    var deedsRepository: DeedsRepository!

    override func setUpWithError() throws {
        persistence = PersistenceController(inMemory: true)
        let context = persistence.viewContext
        deedsRepository = DeedsRepository(context: context)
        entriesRepository = EntriesRepository(context: context)
    }

    override func tearDownWithError() throws {
        persistence = nil
        entriesRepository = nil
        deedsRepository = nil
    }

    func testPositiveBooleanAwardsFullPointsOncePerDay() throws {
        let card = DeedCard(
            name: "Daily Walk",
            emoji: "🚶",
            colorHex: "#FFFFFF",
            category: "Health",
            polarity: .positive,
            unitType: .boolean,
            unitLabel: "completion",
            pointsPerUnit: 15,
            dailyCap: 1,
            isPrivate: false
        )
        try deedsRepository.upsert(card)

        let timestamp = Date()
        let first = try entriesRepository.logEntry(
            EntryCreationRequest(deedId: card.id, timestamp: timestamp, amount: 1, note: nil),
            cutoffHour: 4
        )
        XCTAssertEqual(first.entry.computedPoints, 15)
        XCTAssertFalse(first.wasCapped)

        let second = try entriesRepository.logEntry(
            EntryCreationRequest(deedId: card.id, timestamp: timestamp.addingTimeInterval(3600), amount: 1, note: nil),
            cutoffHour: 4
        )
        XCTAssertEqual(second.entry.computedPoints, 0)
        XCTAssertTrue(second.wasCapped)

        let entries = try entriesRepository.fetchEntries(forDeed: card.id)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.map { $0.computedPoints }, [15, 0])
    }

    func testPositiveBooleanClampsMultipleCompletionsInSingleEntry() throws {
        let card = DeedCard(
            name: "Meditation",
            emoji: "🧘",
            colorHex: "#FFFFFF",
            category: "Wellness",
            polarity: .positive,
            unitType: .boolean,
            unitLabel: "completion",
            pointsPerUnit: 20,
            dailyCap: 1,
            isPrivate: false
        )
        try deedsRepository.upsert(card)

        let timestamp = Date()
        let entry = try entriesRepository.logEntry(
            EntryCreationRequest(deedId: card.id, timestamp: timestamp, amount: 3, note: nil),
            cutoffHour: 4
        )

        XCTAssertEqual(entry.entry.computedPoints, 20)
        XCTAssertTrue(entry.wasCapped)
    }
}
