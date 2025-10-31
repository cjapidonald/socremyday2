import Combine
import CoreData
import Foundation
import SwiftUI

@MainActor
final class DeedsPageViewModel: ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()
    struct CardState: Identifiable, Equatable {
        var card: DeedCard
        var lastUsed: Date?
        var lastAmount: Double?
        var todayCount: Int

        var id: UUID { card.id }

        var accentColor: Color { Color(hex: card.colorHex, fallback: .accentColor) }
        var isPositive: Bool { card.polarity == .positive }
    }

    private var deedsRepository: DeedsRepository
    private var entriesRepository: EntriesRepository
    private var prefsRepository: AppPrefsRepository
    private var scoresRepository: ScoresRepository
    private let lastAmountStore = LastAmountStore()

    @Published var cards: [CardState] = []
    @Published var weeklyNetScore: Double = 0
    @Published var sparklineValues: [Double] = Array(repeating: 0, count: 7)
    @Published private(set) var cutoffHour: Int = 4
    @Published var pendingRatingCard: CardState?
    @Published var categorySuggestions: [String] = []

    private var hasLoaded = false
    private var persistenceController: PersistenceController?
    private var observers: [NSObjectProtocol] = []
    private var isReordering = false

    init(persistenceController: PersistenceController? = nil) {
        let persistenceController = persistenceController ?? .shared
        self.persistenceController = persistenceController
        let context = persistenceController.viewContext
        self.deedsRepository = DeedsRepository(context: context)
        self.entriesRepository = EntriesRepository(context: context)
        self.prefsRepository = AppPrefsRepository(context: context)
        self.scoresRepository = ScoresRepository(context: context)

        // Observe Core Data changes to reload when CloudKit syncs
        setupContextObserver(context: context)

        // Don't load data here - wait for configureIfNeeded to be called
        // This ensures we use the correct AppEnvironment context
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupContextObserver(context: NSManagedObjectContext) {
        // Observe local context saves
        let saveObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: context,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self, self.hasLoaded, !self.isReordering else { return }
                self.reload()
            }
        }

        // Observe CloudKit remote changes
        let remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self, self.hasLoaded, !self.isReordering else { return }
                self.reload()
            }
        }

        observers.append(saveObserver)
        observers.append(remoteChangeObserver)
    }

    func configureIfNeeded(environment: AppEnvironment) {
        guard !hasLoaded else {
            print("⚠️ DeedsPageViewModel already configured")
            return
        }

        print("✅ Configuring DeedsPageViewModel...")
        hasLoaded = true

        persistenceController = environment.persistenceController
        let context = environment.persistenceController.viewContext
        deedsRepository = DeedsRepository(context: context)
        entriesRepository = EntriesRepository(context: context)
        prefsRepository = AppPrefsRepository(context: context)
        scoresRepository = ScoresRepository(context: context)

        // Remove old observers if any
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()

        // Setup new observers with updated context
        setupContextObserver(context: context)

        // Load data immediately
        print("📊 Loading initial data...")
        reload()
        print("✅ Initial load complete. Cards count: \(cards.count)")

        // If no cards loaded, try again after a short delay
        // This handles cases where Core Data hasn't fully initialized yet
        if cards.isEmpty {
            print("⚠️ No cards found on initial load, scheduling retry...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                print("🔄 Retrying data load...")
                self.reload()
                print("✅ Retry complete. Cards count: \(self.cards.count)")
            }
        }
    }

    func reload() {
        print("🔄 Reload called...")
        do {
            let prefs = try prefsRepository.fetch()
            cutoffHour = prefs.dayCutoffHour

            let cards = try deedsRepository.fetchAll(includeArchived: false)
            print("📦 Fetched \(cards.count) cards from repository")
            let entries = try entriesRepository.fetchEntries()
            print("📝 Fetched \(entries.count) entries")

            var lastUsed: [UUID: Date] = [:]
            var lastAmount: [UUID: Double] = [:]
            for entry in entries.sorted(by: { $0.timestamp < $1.timestamp }) {
                lastUsed[entry.deedId] = entry.timestamp
                lastAmount[entry.deedId] = entry.amount
            }

            let sortedCards = cards
                .filter { !$0.isArchived }
                .sorted { lhs, rhs in
                    if lhs.sortOrder != rhs.sortOrder {
                        return lhs.sortOrder < rhs.sortOrder
                    }
                    if lhs.createdAt != rhs.createdAt {
                        return lhs.createdAt < rhs.createdAt
                    }
                    return lhs.id.uuidString < rhs.id.uuidString
                }

            var rememberedAmounts = lastAmount
            for card in sortedCards {
                if rememberedAmounts[card.id] == nil, let stored = lastAmountStore.amount(for: card.id) {
                    rememberedAmounts[card.id] = stored
                }
            }

            // Compute today's entry count for each deed
            let todayRange = appDayRange(for: Date(), cutoffHour: cutoffHour)
            let todayEntries = entries.filter { $0.timestamp >= todayRange.start && $0.timestamp < todayRange.end }
            var todayCount: [UUID: Int] = [:]
            for entry in todayEntries {
                todayCount[entry.deedId, default: 0] += 1
            }

            let limitedCards = Array(sortedCards.prefix(14))
            let categories = Set(cards.map { $0.category }.filter { !$0.isEmpty })
            categorySuggestions = categories.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            self.cards = limitedCards.map { card in
                CardState(
                    card: card,
                    lastUsed: lastUsed[card.id],
                    lastAmount: rememberedAmounts[card.id],
                    todayCount: todayCount[card.id] ?? 0
                )
            }

            let sparkline = try computeSparkline()
            sparklineValues = sparkline
            weeklyNetScore = sparkline.reduce(0, +)
        } catch {
            assertionFailure("Failed to load deeds: \(error)")
        }
    }

    func updateCutoffHour(_ hour: Int) {
        guard cutoffHour != hour else { return }
        cutoffHour = hour

        do {
            let sparkline = try computeSparkline()
            sparklineValues = sparkline
            weeklyNetScore = sparkline.reduce(0, +)
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
        case .count, .rating:
            return 1
        case .duration:
            return 5
        case .quantity:
            return 250
        }
    }

    func prepareTap(on card: CardState) -> LogEntryResult? {
        if card.card.unitType == .rating, card.lastAmount == nil {
            pendingRatingCard = card
            return nil
        }
        let amount = defaultAmount(for: card)
        return log(cardID: card.id, amount: amount, note: nil)
    }

    func confirmRatingSelection(_ rating: Int) -> LogEntryResult? {
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
    func log(cardID: UUID, amount: Double, note: String?) -> LogEntryResult? {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return nil }
        _ = cards[index].card
        let timestamp = Date()
        let request = EntryCreationRequest(
            deedId: cardID,
            timestamp: timestamp,
            amount: amount,
            note: note
        )
        do {
            let result = try entriesRepository.logEntry(request, cutoffHour: cutoffHour)
            let entry = result.entry
            cards[index].lastUsed = entry.timestamp
            cards[index].lastAmount = entry.amount
            lastAmountStore.setAmount(entry.amount, for: cardID)
            if isDate(entry.timestamp, inSameAppDayAs: Date()) {
                cards[index].todayCount += 1
                if !sparklineValues.isEmpty {
                    sparklineValues[sparklineValues.count - 1] += entry.computedPoints
                }
            } else {
                let sparkline = try computeSparkline()
                sparklineValues = sparkline
            }
            weeklyNetScore = sparklineValues.reduce(0, +)
            return result
        } catch {
            assertionFailure("Failed to log entry: \(error)")
            return nil
        }
    }

    func undoLastEntry(for cardID: UUID) -> DeedEntry? {
        do {
            // Fetch all entries for this deed
            let entries = try entriesRepository.fetchEntries(forDeed: cardID)

            // Get the last (most recent) entry
            guard let lastEntry = entries.sorted(by: { $0.timestamp > $1.timestamp }).first else {
                return nil
            }

            // Delete the entry
            try entriesRepository.deleteEntry(id: lastEntry.id)

            // Update the card state
            if let index = cards.firstIndex(where: { $0.id == cardID }) {
                // Decrement today's count if the entry was from today
                if isDate(lastEntry.timestamp, inSameAppDayAs: Date()) {
                    cards[index].todayCount = max(0, cards[index].todayCount - 1)
                }

                // Update sparkline
                let sparkline = try computeSparkline()
                sparklineValues = sparkline
                weeklyNetScore = sparklineValues.reduce(0, +)
            }

            return lastEntry
        } catch {
            assertionFailure("Failed to undo entry: \(error)")
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

    func moveCard(id: UUID, over targetID: UUID) {
        guard let sourceIndex = cards.firstIndex(where: { $0.id == id }),
              let targetIndex = cards.firstIndex(where: { $0.id == targetID }) else { return }
        if sourceIndex == targetIndex { return }

        var updatedCards = cards
        let movingCard = updatedCards.remove(at: sourceIndex)
        let destinationIndex: Int
        if targetIndex > sourceIndex {
            destinationIndex = min(targetIndex, updatedCards.count)
        } else {
            destinationIndex = max(0, targetIndex)
        }
        updatedCards.insert(movingCard, at: destinationIndex)

        applySortOrder(to: &updatedCards)

        cards = updatedCards
    }

    func moveCard(id: UUID, to destinationIndex: Int) {
        guard let sourceIndex = cards.firstIndex(where: { $0.id == id }) else { return }

        let clampedDestination = max(0, min(destinationIndex, cards.count - 1))
        if sourceIndex == clampedDestination { return }

        var updatedCards = cards
        let movingCard = updatedCards.remove(at: sourceIndex)
        let adjustedDestination = max(0, min(clampedDestination, updatedCards.count))
        updatedCards.insert(movingCard, at: adjustedDestination)

        applySortOrder(to: &updatedCards)

        cards = updatedCards
    }

    func reorderCards(by orderedIDs: [UUID]) {
        guard orderedIDs.count == cards.count else { return }

        isReordering = true

        let lookup = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        var updatedCards: [CardState] = []
        updatedCards.reserveCapacity(cards.count)

        for id in orderedIDs {
            guard let card = lookup[id] else {
                isReordering = false
                return
            }
            updatedCards.append(card)
        }

        applySortOrder(to: &updatedCards)

        cards = updatedCards
    }

    private func applySortOrder(to cards: inout [CardState]) {
        let baseOrder = self.cards.map { $0.card.sortOrder }.min() ?? 0
        for index in cards.indices {
            cards[index].card.sortOrder = baseOrder + index
        }
    }

    func persistCardOrder() {
        do {
            try deedsRepository.updateSortOrders(cards.map { $0.card })
            // Clear the reordering flag after a short delay to allow the save to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.isReordering = false
            }
        } catch {
            assertionFailure("Failed to persist card order: \(error)")
            isReordering = false
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

struct DailyCapHintStore {
    private let defaults: UserDefaults
    private let keyPrefix = "deedDailyCapHint."

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }

    func shouldShowHint(
        for cardID: UUID,
        on date: Date,
        cutoffHour: Int,
        calendar: Calendar = .current
    ) -> Bool {
        let key = storageKey(for: cardID)
        let dayStart = appDayRange(for: date, cutoffHour: cutoffHour, calendar: calendar).start
        guard let stored = defaults.object(forKey: key) as? Double else {
            return true
        }
        let target = dayStart.timeIntervalSinceReferenceDate
        return abs(stored - target) > 0.5
    }

    func markHintShown(
        for cardID: UUID,
        on date: Date,
        cutoffHour: Int,
        calendar: Calendar = .current
    ) {
        let key = storageKey(for: cardID)
        let dayStart = appDayRange(for: date, cutoffHour: cutoffHour, calendar: calendar).start
        defaults.set(dayStart.timeIntervalSinceReferenceDate, forKey: key)
    }

    private func storageKey(for cardID: UUID) -> String {
        keyPrefix + cardID.uuidString
    }
}
