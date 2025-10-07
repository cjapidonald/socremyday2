import Foundation

struct DeedSuggestion: Identifiable, Equatable {
    enum Kind: String {
        case hydration
        case meditation
        case positiveLog
    }

    let kind: Kind
    let cardID: UUID

    var id: String { "\(kind.rawValue)-\(cardID.uuidString)" }
}

struct DeedSuggestionsService {
    private let hydrationKeywords = ["water", "hydrate", "hydration", "h2o"]
    private let hydrationEmojis: Set<String> = ["💧", "🚰", "🫗", "🥤", "🧊"]
    private let meditationKeywords = ["meditate", "meditation", "mindful", "breath", "breathing"]
    private let meditationEmojis: Set<String> = ["🧘", "🧘‍♀️", "🧘‍♂️"]
    private let positiveKeywords = ["positive", "gratitude", "journal", "log", "highlight", "win", "wins"]

    func makeSuggestions(
        cards: [DeedCard],
        entries: [DeedEntry],
        cutoffHour: Int,
        referenceDate: Date = Date()
    ) -> [DeedSuggestion] {
        guard !cards.isEmpty else { return [] }

        let dayRange = appDayRange(for: referenceDate, cutoffHour: cutoffHour)
        let todaysEntries = entries.filter { entry in
            entry.timestamp >= dayRange.start && entry.timestamp < dayRange.end
        }
        let entriesByCard = Dictionary(grouping: todaysEntries, by: { $0.deedId })

        var suggestions: [DeedSuggestion] = []
        var usedCardIDs: Set<UUID> = []

        if let hydration = hydrationSuggestion(from: cards, entriesByCard: entriesByCard, usedCardIDs: &usedCardIDs) {
            suggestions.append(hydration)
        }

        if suggestions.count < 2,
           let meditation = meditationSuggestion(from: cards, entriesByCard: entriesByCard, usedCardIDs: &usedCardIDs) {
            suggestions.append(meditation)
        }

        if suggestions.count < 2,
           let positive = positiveLogSuggestion(
                from: cards,
                entriesByCard: entriesByCard,
                todaysEntries: todaysEntries,
                usedCardIDs: &usedCardIDs
           ) {
            suggestions.append(positive)
        }

        return Array(suggestions.prefix(2))
    }

    private func hydrationSuggestion(
        from cards: [DeedCard],
        entriesByCard: [UUID: [DeedEntry]],
        usedCardIDs: inout Set<UUID>
    ) -> DeedSuggestion? {
        guard let card = cards.first(where: { candidate in
            guard candidate.polarity == .positive else { return false }
            guard entriesByCard[candidate.id] == nil else { return false }
            let name = candidate.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
            if hydrationKeywords.contains(where: { name.contains($0) }) { return true }
            return hydrationEmojis.contains(candidate.emoji)
        }) else {
            return nil
        }

        usedCardIDs.insert(card.id)
        return DeedSuggestion(kind: .hydration, cardID: card.id)
    }

    private func meditationSuggestion(
        from cards: [DeedCard],
        entriesByCard: [UUID: [DeedEntry]],
        usedCardIDs: inout Set<UUID>
    ) -> DeedSuggestion? {
        guard let card = cards.first(where: { candidate in
            guard candidate.polarity == .positive else { return false }
            guard !usedCardIDs.contains(candidate.id) else { return false }
            guard entriesByCard[candidate.id] == nil else { return false }
            let name = candidate.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
            if meditationKeywords.contains(where: { name.contains($0) }) { return true }
            return meditationEmojis.contains(candidate.emoji)
        }) else {
            return nil
        }

        usedCardIDs.insert(card.id)
        return DeedSuggestion(kind: .meditation, cardID: card.id)
    }

    private func positiveLogSuggestion(
        from cards: [DeedCard],
        entriesByCard: [UUID: [DeedEntry]],
        todaysEntries: [DeedEntry],
        usedCardIDs: inout Set<UUID>
    ) -> DeedSuggestion? {
        let hasPositiveEntry = todaysEntries.contains(where: { $0.computedPoints > 0 })
        guard !hasPositiveEntry else { return nil }

        let enumerated = cards.enumerated().filter { element in
            let card = element.element
            guard card.polarity == .positive else { return false }
            guard !usedCardIDs.contains(card.id) else { return false }
            guard entriesByCard[card.id] == nil else { return false }
            return card.unitType != .rating
        }

        guard !enumerated.isEmpty else { return nil }

        let prioritized = enumerated.sorted { lhs, rhs in
            let lhsPriority = positivePriority(for: lhs.element)
            let rhsPriority = positivePriority(for: rhs.element)
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }

            let lhsMatches = matchesPositiveKeyword(lhs.element)
            let rhsMatches = matchesPositiveKeyword(rhs.element)
            if lhsMatches != rhsMatches {
                return lhsMatches
            }

            return lhs.offset < rhs.offset
        }

        guard let card = prioritized.first?.element else { return nil }
        usedCardIDs.insert(card.id)
        return DeedSuggestion(kind: .positiveLog, cardID: card.id)
    }

    private func positivePriority(for card: DeedCard) -> Int {
        switch card.unitType {
        case .boolean:
            return 0
        case .count:
            return 1
        case .duration:
            return 2
        case .quantity:
            return 3
        case .rating:
            return 4
        }
    }

    private func matchesPositiveKeyword(_ card: DeedCard) -> Bool {
        let name = card.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased()
        return positiveKeywords.contains(where: { name.contains($0) })
    }
}
