import CoreData
import XCTest
@testable import scoremyday2

final class EntriesRepositoryTests: XCTestCase {
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

    func testDailyCapLimitsPointsPerAppDay() throws {
        let card = DeedCard(
            name: "Meditation",
            emoji: "🧘",
            colorHex: "#FFFFFF",
            category: "Wellness",
            polarity: .positive,
            unitType: .duration,
            unitLabel: "minutes",
            pointsPerUnit: 5,
            dailyCap: 10,
            isPrivate: false
        )
        try deedsRepository.upsert(card)

        let timestamp = Date()
        let first = try entriesRepository.logEntry(
            EntryCreationRequest(deedId: card.id, timestamp: timestamp, amount: 1, note: nil),
            cutoffHour: 4
        )
        XCTAssertEqual(first.entry.computedPoints, 5)
        XCTAssertFalse(first.wasCapped)

        let second = try entriesRepository.logEntry(
            EntryCreationRequest(deedId: card.id, timestamp: timestamp.addingTimeInterval(3600), amount: 2, note: nil),
            cutoffHour: 4
        )
        XCTAssertEqual(second.entry.computedPoints, 5)
        XCTAssertTrue(second.wasCapped)

        let third = try entriesRepository.logEntry(
            EntryCreationRequest(deedId: card.id, timestamp: timestamp.addingTimeInterval(7200), amount: 1, note: nil),
            cutoffHour: 4
        )
        XCTAssertEqual(third.entry.computedPoints, 0)
        XCTAssertTrue(third.wasCapped)

        let entries = try entriesRepository.fetchEntries(forDeed: card.id)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries.map { $0.computedPoints }, [5, 5, 0])
    }
}
