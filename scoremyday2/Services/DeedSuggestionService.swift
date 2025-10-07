import Foundation

struct DeedSuggestionService {
    struct CardInput {
        let card: DeedCard
        let lastUsed: Date?
    }

    enum Kind: String {
        case hydration
        case meditation
        case positivity

        var displayTitle: String {
            switch self {
            case .hydration:
                return "Hydrate"
            case .meditation:
                return "Take a moment"
            case .positivity:
                return "Boost your mood"
            }
        }
    }

    struct Suggestion {
        let kind: Kind
        let cardID: UUID
        let targetAmount: Double?
        let note: String?
    }

    func suggestions(
        for cards: [CardInput],
        entries: [DeedEntry],
        cutoffHour: Int,
        referenceDate: Date = Date()
    ) -> [Suggestion] {
        guard !cards.isEmpty else { return [] }

        let dayRange = appDayRange(for: referenceDate, cutoffHour: cutoffHour)
        let todaysEntries = entries
            .filter { entry in
                entry.timestamp >= dayRange.start && entry.timestamp < dayRange.end
            }
            .sorted { $0.timestamp < $1.timestamp }
        let entriesByCard = Dictionary(grouping: todaysEntries, by: { $0.deedId })

        var results: [Suggestion] = []
        var excluded: Set<UUID> = []

        if let hydration = hydrationSuggestion(cards: cards, entriesByCard: entriesByCard, referenceDate: referenceDate, excluding: excluded) {
            results.append(hydration)
            excluded.insert(hydration.cardID)
        }

        if results.count < 2,
           let meditation = meditationSuggestion(cards: cards, entriesByCard: entriesByCard, excluding: excluded) {
            results.append(meditation)
            excluded.insert(meditation.cardID)
        }

        if results.count < 2,
           let positivity = positivitySuggestion(cards: cards, todaysEntries: todaysEntries, excluding: excluded, referenceDate: referenceDate) {
            results.append(positivity)
        }

        return Array(results.prefix(2))
    }

    private func hydrationSuggestion(
        cards: [CardInput],
        entriesByCard: [UUID: [DeedEntry]],
        referenceDate: Date,
        excluding excluded: Set<UUID>
    ) -> Suggestion? {
        let keywords = ["water", "hydrate", "hydration", "drink"]
        let hydrationCards = cards.filter { input in
            guard !excluded.contains(input.card.id) else { return false }
            guard input.card.polarity == .positive, input.card.unitType == .quantity else { return false }
            let name = input.card.name.lowercased()
            let label = input.card.unitLabel.lowercased()
            let category = input.card.category.lowercased()
            if keywords.contains(where: { name.contains($0) || label.contains($0) || category.contains($0) }) {
                return true
            }
            return input.card.emoji.contains("💧")
        }

        guard let candidate = hydrationCards.first else { return nil }
        let todaysAmount = entriesByCard[candidate.card.id]?.reduce(0) { $0 + max(0, $1.amount) } ?? 0
        let lastEntry = entriesByCard[candidate.card.id]?.max(by: { $0.timestamp < $1.timestamp })?.timestamp
        let hydrationGoal: Double = 2000
        let minimumSpacing: TimeInterval = 60 * 75 // 1h 15m
        let needsMoreToday = todaysAmount < hydrationGoal
        let spacedOut = lastEntry.map { referenceDate.timeIntervalSince($0) >= minimumSpacing } ?? true
        guard needsMoreToday && spacedOut else { return nil }

        return Suggestion(kind: .hydration, cardID: candidate.card.id, targetAmount: nil, note: nil)
    }

    private func meditationSuggestion(
        cards: [CardInput],
        entriesByCard: [UUID: [DeedEntry]],
        excluding excluded: Set<UUID>
    ) -> Suggestion? {
        let keywords = ["meditat", "mindful", "breathe", "breath", "calm"]
        for input in cards where !excluded.contains(input.card.id) {
            guard input.card.polarity == .positive, input.card.unitType == .duration else { continue }
            let name = input.card.name.lowercased()
            let category = input.card.category.lowercased()
            guard keywords.contains(where: { name.contains($0) || category.contains($0) }) else { continue }
            let hasEntryToday = entriesByCard[input.card.id]?.isEmpty == false
            if !hasEntryToday {
                return Suggestion(kind: .meditation, cardID: input.card.id, targetAmount: nil, note: nil)
            }
        }
        return nil
    }

    private func positivitySuggestion(
        cards: [CardInput],
        todaysEntries: [DeedEntry],
        excluding excluded: Set<UUID>,
        referenceDate: Date
    ) -> Suggestion? {
        let negativeEntries = todaysEntries.filter { $0.computedPoints < 0 }
        guard let latestNegative = negativeEntries.max(by: { $0.timestamp < $1.timestamp }) else { return nil }
        let recentWindow: TimeInterval = 60 * 120 // 2 hours
        guard referenceDate.timeIntervalSince(latestNegative.timestamp) <= recentWindow else { return nil }
        let positiveAfterNegative = todaysEntries.first { entry in
            entry.computedPoints > 0 && entry.timestamp > latestNegative.timestamp
        }
        guard positiveAfterNegative == nil else { return nil }

        for input in cards where !excluded.contains(input.card.id) {
            guard input.card.polarity == .positive else { continue }
            return Suggestion(kind: .positivity, cardID: input.card.id, targetAmount: nil, note: nil)
        }
        return nil
    }
}
