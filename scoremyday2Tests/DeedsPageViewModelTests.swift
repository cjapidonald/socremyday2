import XCTest
@testable import scoremyday2

@MainActor
final class DeedsPageViewModelTests: XCTestCase {
    func testNewCardAppearsFirstBeforeLogging() throws {
        let persistence = PersistenceController(inMemory: true)
        let viewModel = DeedsPageViewModel(persistenceController: persistence)

        viewModel.reload()

        let newCard = DeedCard(
            name: "Regression Card",
            emoji: "🧪",
            colorHex: "#FFFFFF",
            category: "Testing",
            polarity: .positive,
            unitType: .count,
            unitLabel: "time",
            pointsPerUnit: 1,
            dailyCap: nil,
            isPrivate: false,
            createdAt: Date().addingTimeInterval(5)
        )

        viewModel.upsert(card: newCard)

        XCTAssertEqual(viewModel.cards.first?.id, newCard.id)

        viewModel.reload()

        XCTAssertEqual(viewModel.cards.first?.id, newCard.id)
    }
}
