import Foundation
import SwiftUI

@MainActor
final class DeedsPageViewModel: ObservableObject {
    struct CardState: Identifiable, Equatable {
        let card: DeedCard
        var lastUsed: Date?
        var lastAmount: Double?

        var id: UUID { card.id }

        var accentColor: Color { Color(hex: card.colorHex, fallback: .accentColor) }
        var isPositive: Bool { card.polarity == .positive }
    }

    private let deedsRepository: DeedsRepository
    private let entriesRepository: EntriesRepository
    private let prefsRepository: AppPrefsRepository
    private let scoresRepository: ScoresRepository
    private let lastAmountStore = LastAmountStore()

    @Published var cards: [CardState] = []
    @Published var todayNetScore: Double = 0
    @Published var sparklineValues: [Double] = Array(repeating: 0, count: 7)
    @Published private(set) var cutoffHour: Int = 4
    @Published var pendingRatingCard: CardState?
    @Published var categorySuggestions: [String] = []

    private var hasLoaded = false

    init(persistenceController: PersistenceController = .shared) {
        let context = persistenceController.viewContext
        self.deedsRepository = DeedsRepository(context: context)
        self.entriesRepository = EntriesRepository(context: context)
        self.prefsRepository = AppPrefsRepository(context: context)
        self.scoresRepository = ScoresRepository(context: context)
    }

    func onAppear() {
        guard !hasLoaded else { return }
        hasLoaded = true
        reload()
    }

    func reload() {
        do {
            let prefs = try prefsRepository.fetch()
            cutoffHour = prefs.dayCutoffHour

            let cards = try deedsRepository.fetchAll(includeArchived: false)
            let entries = try entriesRepository.fetchEntries()

            var lastUsed: [UUID: Date] = [:]
            var lastAmount: [UUID: Double] = [:]
            for entry in entries.sorted(by: { $0.timestamp < $1.timestamp }) {
                lastUsed[entry.deedId] = entry.timestamp
                lastAmount[entry.deedId] = entry.amount
            }

            let sortedCards = cards
                .filter { !$0.isArchived }
                .sorted { lhs, rhs in
                    let lhsDate = lastUsed[lhs.id]
                    let rhsDate = lastUsed[rhs.id]
                    if let lhsDate, let rhsDate, lhsDate != rhsDate {
                        return lhsDate > rhsDate
                    } else if (lhsDate != nil) != (rhsDate != nil) {
                        return lhsDate != nil
                    } else {
                        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                    }
                }

            var rememberedAmounts = lastAmount
            for card in sortedCards {
                if rememberedAmounts[card.id] == nil, let stored = lastAmountStore.amount(for: card.id) {
                    rememberedAmounts[card.id] = stored
                }
            }

            let limitedCards = Array(sortedCards.prefix(14))
            let categories = Set(cards.map { $0.category }.filter { !$0.isEmpty })
            categorySuggestions = categories.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            self.cards = limitedCards.map { card in
                CardState(
                    card: card,
                    lastUsed: lastUsed[card.id],
                    lastAmount: rememberedAmounts[card.id]
                )
            }

            todayNetScore = try computeTodayScore()
            sparklineValues = try computeSparkline()
        } catch {
            assertionFailure("Failed to load deeds: \(error)")
        }
    }

    func updateCutoffHour(_ hour: Int) {
        guard cutoffHour != hour else { return }
        cutoffHour = hour

        do {
            todayNetScore = try computeTodayScore()
            sparklineValues = try computeSparkline()
        } catch {
            assertionFailure("Failed to recompute metrics: \(error)")
        }
    }

    func upsert(card: DeedCard) {
        do {
            try deedsRepository.upsert(card)
            reload()
        } catch {
            assertionFailure("Failed to upsert deed: \(error)")
        }
    }

    private func computeTodayScore(reference date: Date = Date()) throws -> Double {
        let range = appDayRange(for: date, cutoffHour: cutoffHour)
        let entries = try entriesRepository.fetchEntries(in: range.start...range.end)
        return entries.reduce(0) { $0 + $1.computedPoints }
    }

    private func computeSparkline(reference date: Date = Date()) throws -> [Double] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        guard let start = calendar.date(byAdding: .day, value: -6, to: date) else {
            return Array(repeating: 0, count: 7)
        }
        let scores = try scoresRepository.dailyScores(in: start...date, cutoffHour: cutoffHour)
        var mapped: [Date: Double] = [:]
        for score in scores {
            mapped[score.dayStart] = score.totalPoints
        }
        return (0..<7).map { offset -> Double in
            let day = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            let bucket = appDayRange(for: day, cutoffHour: cutoffHour, calendar: calendar).start
            return mapped[bucket] ?? 0
        }
    }

    func defaultAmount(for card: CardState) -> Double {
        if let lastAmount = card.lastAmount { return lastAmount }
        switch card.card.unitType {
        case .count, .boolean, .rating:
            return 1
        case .duration:
            return 5
        case .quantity:
            return 250
        }
    }

    func prepareTap(on card: CardState) -> DeedEntry? {
        if card.card.unitType == .rating, card.lastAmount == nil {
            pendingRatingCard = card
            return nil
        }
        let amount = defaultAmount(for: card)
        return log(cardID: card.id, amount: amount, note: nil)
    }

    func confirmRatingSelection(_ rating: Int) -> DeedEntry? {
        guard var card = pendingRatingCard else { return nil }
        pendingRatingCard = nil
        let amount = Double(rating)
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            cards[index].lastAmount = amount
            card = cards[index]
        }
        return log(cardID: card.id, amount: amount, note: nil)
    }

    @discardableResult
    func log(cardID: UUID, amount: Double, note: String?) -> DeedEntry? {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return nil }
        let card = cards[index].card
        let timestamp = Date()
        let request = EntryCreationRequest(
            deedId: cardID,
            timestamp: timestamp,
            amount: amount,
            note: note
        )
        do {
            let entry = try entriesRepository.logEntry(request, cutoffHour: cutoffHour)
            cards[index].lastUsed = entry.timestamp
            cards[index].lastAmount = entry.amount
            lastAmountStore.setAmount(entry.amount, for: cardID)
            resortCards()
            if isDate(entry.timestamp, inSameAppDayAs: Date()) {
                todayNetScore += entry.computedPoints
                if !sparklineValues.isEmpty {
                    sparklineValues[sparklineValues.count - 1] += entry.computedPoints
                }
            } else {
                todayNetScore = try computeTodayScore()
                sparklineValues = try computeSparkline()
            }
            return entry
        } catch {
            assertionFailure("Failed to log entry: \(error)")
            return nil
        }
    }

    func toggleArchive(for cardID: UUID) {
        do {
            guard var card = try deedsRepository.get(id: cardID) else { return }
            card.isArchived.toggle()
            try deedsRepository.upsert(card)
            reload()
        } catch {
            assertionFailure("Failed to toggle archive: \(error)")
        }
    }

    func setShowOnStats(_ isVisible: Bool, for cardID: UUID) {
        do {
            guard var card = try deedsRepository.get(id: cardID) else { return }
            guard card.showOnStats != isVisible else { return }
            card.showOnStats = isVisible
            try deedsRepository.upsert(card)
            reload()
        } catch {
            assertionFailure("Failed to update stats visibility: \(error)")
        }
    }

    private func resortCards() {
        cards.sort { lhs, rhs in
            if let lhsDate = lhs.lastUsed, let rhsDate = rhs.lastUsed, lhsDate != rhsDate {
                return lhsDate > rhsDate
            } else if (lhs.lastUsed != nil) != (rhs.lastUsed != nil) {
                return lhs.lastUsed != nil
            } else {
                return lhs.card.name.localizedCaseInsensitiveCompare(rhs.card.name) == .orderedAscending
            }
        }
    }

    private func isDate(_ date: Date, inSameAppDayAs reference: Date) -> Bool {
        let range = appDayRange(for: reference, cutoffHour: cutoffHour)
        return date >= range.start && date < range.end
    }
}

private struct LastAmountStore {
    private let defaults: UserDefaults
    private let keyPrefix = "deedLastAmount."

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }

    func amount(for id: UUID) -> Double? {
        defaults.object(forKey: keyPrefix + id.uuidString) as? Double
    }

    func setAmount(_ amount: Double, for id: UUID) {
        defaults.set(amount, forKey: keyPrefix + id.uuidString)
    }
}
