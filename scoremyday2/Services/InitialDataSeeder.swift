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
            name: "Brush Teeth",
            emoji: "🪥",
            category: "Health",
            polarity: .positive,
            unitType: .count,
            unitLabel: "time",
            pointsPerUnit: 5,
            dailyCap: 2,
            colorHex: "#5ED3F3",
            isPrivate: false
        ),
        DefaultDeedCardSeed(
            name: "Pray",
            emoji: "🙏",
            category: "Faith",
            polarity: .positive,
            unitType: .count,
            unitLabel: "rak'ah",
            pointsPerUnit: 20,
            dailyCap: nil,
            colorHex: "#9B59B6",
            isPrivate: false
        ),
        DefaultDeedCardSeed(
            name: "Read Book",
            emoji: "📖",
            category: "Learning",
            polarity: .positive,
            unitType: .duration,
            unitLabel: "min",
            pointsPerUnit: 1.5,
            dailyCap: 120,
            colorHex: "#F5B041",
            isPrivate: false
        ),
        DefaultDeedCardSeed(
            name: "Meditation",
            emoji: "🧘",
            category: "Wellbeing",
            polarity: .positive,
            unitType: .duration,
            unitLabel: "min",
            pointsPerUnit: 2,
            dailyCap: 60,
            colorHex: "#2ECC71",
            isPrivate: false
        ),
        DefaultDeedCardSeed(
            name: "Drink Water",
            emoji: "💧",
            category: "Health",
            polarity: .positive,
            unitType: .quantity,
            unitLabel: "ml",
            pointsPerUnit: 0.02,
            dailyCap: 4000,
            colorHex: "#3498DB",
            isPrivate: false
        ),
        DefaultDeedCardSeed(
            name: "Family Time",
            emoji: "👨‍👩‍👧",
            category: "Relationships",
            polarity: .positive,
            unitType: .duration,
            unitLabel: "min",
            pointsPerUnit: 1,
            dailyCap: 180,
            colorHex: "#E67E22",
            isPrivate: false
        ),
        DefaultDeedCardSeed(
            name: "Workout",
            emoji: "🏋️",
            category: "Health",
            polarity: .positive,
            unitType: .duration,
            unitLabel: "min",
            pointsPerUnit: 2.5,
            dailyCap: 120,
            colorHex: "#E74C3C",
            isPrivate: false
        ),
        DefaultDeedCardSeed(
            name: "No Phone after 10pm",
            emoji: "📵",
            category: "Habits",
            polarity: .positive,
            unitType: .boolean,
            unitLabel: "did it",
            pointsPerUnit: 20,
            dailyCap: 1,
            colorHex: "#16A085",
            isPrivate: false
        ),
        DefaultDeedCardSeed(
            name: "Junk Food",
            emoji: "🍟",
            category: "Diet",
            polarity: .negative,
            unitType: .quantity,
            unitLabel: "serving",
            pointsPerUnit: -15,
            dailyCap: nil,
            colorHex: "#C0392B",
            isPrivate: false
        ),
        DefaultDeedCardSeed(
            name: "Smoked",
            emoji: "🚭",
            category: "Addiction",
            polarity: .negative,
            unitType: .boolean,
            unitLabel: "did it",
            pointsPerUnit: -40,
            dailyCap: nil,
            colorHex: "#8E44AD",
            isPrivate: true
        ),
        DefaultDeedCardSeed(
            name: "Doomscrolling",
            emoji: "📱",
            category: "Habits",
            polarity: .negative,
            unitType: .duration,
            unitLabel: "min",
            pointsPerUnit: -1,
            dailyCap: nil,
            colorHex: "#7F8C8D",
            isPrivate: false
        ),
        DefaultDeedCardSeed(
            name: "Focus Rating",
            emoji: "🎯",
            category: "Work",
            polarity: .positive,
            unitType: .rating,
            unitLabel: "stars",
            pointsPerUnit: 4,
            dailyCap: 5,
            colorHex: "#F1C40F",
            isPrivate: false
        )
    ]
}
