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
            name: "No Phone", 
            emoji: "📵", 
            colorHex: "#FFFFFF", 
            category: "Habits", 
            polarity: .positive, 
            unitType: .boolean, 
            unitLabel: "completion", 
            pointsPerUnit: 20, 
            dailyCap: 1, 
            isPrivate: false
        )
        try deedsRepository.upsert(card)

        let timestamp = Date()

        let first = try entriesRepository.logEntry(
            EntryCreationRequest(deedId: card.id, timestamp: timestamp, amount: 1, note: nil),
            cutoffHour: 4
        )
        XCTAssertEqual(first.computedPoints, 20)

        let second = try entriesRepository.logEntry(
            EntryCreationRequest(deedId: card.id, timestamp: timestamp.addingTimeInterval(3600), amount: 1, note: nil),
            cutoffHour: 4
        )
        XCTAssertEqual(second.computedPoints, 0)

        let third = try entriesRepository.logEntry(
            EntryCreationRequest(deedId: card.id, timestamp: timestamp.addingTimeInterval(86400), amount: 1, note: nil),
            cutoffHour: 4
        )
        XCTAssertEqual(third.computedPoints, 20)

        let entries = try entriesRepository.fetchEntries(forDeed: card.id)
        XCTAssertEqual(entries.map(\.computedPoints), [20, 0, 20])
    }
}
