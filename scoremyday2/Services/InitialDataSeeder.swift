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
    static let all: [DefaultDeedCardSeed] = [
        DefaultDeedCardSeed(
            name: "Morning Walk",
            emoji: "🚶",
            category: "Wellness",
            polarity: .positive,
            unitType: .duration,
            unitLabel: "minutes",
            pointsPerUnit: 4,
            dailyCap: 45,
            colorHex: "#34C759",
            isPrivate: false,
            showOnStats: true
        ),
        DefaultDeedCardSeed(
            name: "Meditation",
            emoji: "🧘",
            category: "Mindfulness",
            polarity: .positive,
            unitType: .duration,
            unitLabel: "minutes",
            pointsPerUnit: 5,
            dailyCap: 30,
            colorHex: "#AF52DE",
            isPrivate: false,
            showOnStats: true
        ),
        DefaultDeedCardSeed(
            name: "Hydrate",
            emoji: "💧",
            category: "Wellness",
            polarity: .positive,
            unitType: .count,
            unitLabel: "glass",
            pointsPerUnit: 3,
            dailyCap: 8,
            colorHex: "#32ADE6",
            isPrivate: false,
            showOnStats: true
        ),
        DefaultDeedCardSeed(
            name: "Healthy Meal",
            emoji: "🥗",
            category: "Nutrition",
            polarity: .positive,
            unitType: .count,
            unitLabel: "meal",
            pointsPerUnit: 12,
            dailyCap: 3,
            colorHex: "#FF9500",
            isPrivate: false,
            showOnStats: true
        ),
        DefaultDeedCardSeed(
            name: "Stretch Break",
            emoji: "🧘‍♀️",
            category: "Wellness",
            polarity: .positive,
            unitType: .duration,
            unitLabel: "minutes",
            pointsPerUnit: 2,
            dailyCap: 20,
            colorHex: "#FF2D55",
            isPrivate: false,
            showOnStats: true
        ),
        DefaultDeedCardSeed(
            name: "Read a Chapter",
            emoji: "📚",
            category: "Growth",
            polarity: .positive,
            unitType: .count,
            unitLabel: "chapter",
            pointsPerUnit: 10,
            dailyCap: 2,
            colorHex: "#FFD60A",
            isPrivate: false,
            showOnStats: true
        ),
        DefaultDeedCardSeed(
            name: "Budget Check",
            emoji: "💸",
            category: "Life",
            polarity: .positive,
            unitType: .boolean,
            unitLabel: "Completed",
            pointsPerUnit: 20,
            dailyCap: 1,
            colorHex: "#FF9F0A",
            isPrivate: false,
            showOnStats: true
        ),
        DefaultDeedCardSeed(
            name: "Sleep Quality",
            emoji: "😴",
            category: "Wellness",
            polarity: .positive,
            unitType: .rating,
            unitLabel: "rating",
            pointsPerUnit: 6,
            dailyCap: nil,
            colorHex: "#0A84FF",
            isPrivate: false,
            showOnStats: true
        ),
        DefaultDeedCardSeed(
            name: "Evening Unplug",
            emoji: "📵",
            category: "Mindfulness",
            polarity: .positive,
            unitType: .boolean,
            unitLabel: "Completed",
            pointsPerUnit: 15,
            dailyCap: 1,
            colorHex: "#30B0C7",
            isPrivate: false,
            showOnStats: true
        ),
        DefaultDeedCardSeed(
            name: "Junk Food",
            emoji: "🍟",
            category: "Nutrition",
            polarity: .negative,
            unitType: .count,
            unitLabel: "serving",
            pointsPerUnit: -8,
            dailyCap: nil,
            colorHex: "#FF453A",
            isPrivate: false,
            showOnStats: true
        ),
        DefaultDeedCardSeed(
            name: "Late Night Scroll",
            emoji: "📱",
            category: "Mindfulness",
            polarity: .negative,
            unitType: .duration,
            unitLabel: "minutes",
            pointsPerUnit: -3,
            dailyCap: nil,
            colorHex: "#5856D6",
            isPrivate: false,
            showOnStats: true
        ),
        DefaultDeedCardSeed(
            name: "Impulse Buy",
            emoji: "🛍️",
            category: "Life",
            polarity: .negative,
            unitType: .boolean,
            unitLabel: "Made purchase",
            pointsPerUnit: -25,
            dailyCap: nil,
            colorHex: "#8E8E93",
            isPrivate: false,
            showOnStats: true
        ),
        DefaultDeedCardSeed(
            name: "Skipped Workout",
            emoji: "🙈",
            category: "Fitness",
            polarity: .negative,
            unitType: .boolean,
            unitLabel: "Skipped",
            pointsPerUnit: -18,
            dailyCap: nil,
            colorHex: "#FF3B30",
            isPrivate: false,
            showOnStats: true
        )
    ]
}
