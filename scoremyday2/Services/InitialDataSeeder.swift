import CoreData
import Foundation

struct DefaultDeedCardSeed {
    let name: String
    let emoji: String
    let category: String
    let polarity: Polarity
    let unitType: UnitType
    let unitLabel: String
    let pointsPerUnit: Double
    let dailyCap: Double?
    let colorHex: String
    let isPrivate: Bool
    let showOnStats: Bool
}

struct InitialDataSeeder {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func runIfNeeded() throws {
        guard try shouldSeedDefaults() else { return }
        try seedDefaultDeedCards()
    }

    @discardableResult
    func seedDefaultDeedCards() throws -> [DeedCardMO] {
        try context.performAndReturn {
            var createdCards: [DeedCardMO] = []
            let now = Date()

            for (index, seed) in DefaultDeedCardSeed.all.enumerated() {
                let card = DeedCardMO(context: context)
                card.id = UUID()
                card.name = seed.name
                card.emoji = seed.emoji
                card.colorHex = seed.colorHex
                card.category = seed.category
                card.polarityRaw = seed.polarity.rawValue
                card.unitTypeRaw = seed.unitType.rawValue
                card.unitLabel = seed.unitLabel
                card.pointsPerUnit = seed.pointsPerUnit
                if let cap = seed.dailyCap {
                    card.dailyCap = NSNumber(value: cap)
                } else {
                    card.dailyCap = nil
                }
                card.isPrivate = seed.isPrivate
                card.showOnStats = seed.showOnStats
                card.createdAt = now.addingTimeInterval(TimeInterval(-index * 60))
                card.isArchived = false
                card.sortOrder = Int32(index)
                createdCards.append(card)
            }

            if context.hasChanges {
                try context.save()
            }

            return createdCards
        }
    }

    private func shouldSeedDefaults() throws -> Bool {
        try context.performAndReturn {
            let cardRequest = DeedCardMO.fetchRequest()
            cardRequest.fetchLimit = 1
            let cardCount = try context.count(for: cardRequest)
            guard cardCount == 0 else { return false }

            let entryRequest = DeedEntryMO.fetchRequest()
            entryRequest.fetchLimit = 1
            let entryCount = try context.count(for: entryRequest)
            return entryCount == 0
        }
    }
}

private extension DefaultDeedCardSeed {
    static let all: [DefaultDeedCardSeed] = []
}
