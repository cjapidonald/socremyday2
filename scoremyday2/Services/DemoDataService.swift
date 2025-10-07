import CoreData
import Foundation

struct DemoDataService {
    private let context: NSManagedObjectContext
    private let deedsRepository: DeedsRepository
    private let entriesRepository: EntriesRepository
    private let prefsRepository: AppPrefsRepository

    init(context: NSManagedObjectContext) {
        self.context = context
        self.deedsRepository = DeedsRepository(context: context)
        self.entriesRepository = EntriesRepository(context: context)
        self.prefsRepository = AppPrefsRepository(context: context)
    }

    init(persistenceController: PersistenceController = .shared) {
        self.init(context: persistenceController.viewContext)
    }

    func loadDemoData() throws {
        try clearExistingData()
        _ = try InitialDataSeeder(context: context).seedDefaultDeedCards()

        let cards = try deedsRepository.fetchAll(includeArchived: false).filter { !$0.isArchived }
        guard !cards.isEmpty else { return }

        let prefs = try prefsRepository.fetch()
        let cutoff = prefs.dayCutoffHour

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let now = Date()

        for dayOffset in 0..<14 {
            guard let referenceDate = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let dayRange = appDayRange(for: referenceDate, cutoffHour: cutoff, calendar: calendar)
            let entryCount = Int.random(in: 10...30)

            for _ in 0..<entryCount {
                guard let card = cards.randomElement() else { continue }
                let timestamp = randomTimestamp(in: dayRange)
                let amount = randomAmount(for: card)
                let note = Bool.random() ? nil : "Demo entry"
                let request = EntryCreationRequest(
                    deedId: card.id,
                    timestamp: timestamp,
                    amount: amount,
                    note: note
                )
                _ = try entriesRepository.logEntry(request, cutoffHour: cutoff)
            }
        }
    }

    func resetAllData() throws {
        try clearExistingData()
        try prefsRepository.update(AppPrefs())
        _ = try InitialDataSeeder(context: context).seedDefaultDeedCards()
    }

    private func clearExistingData() throws {
        try context.performAndReturn {
            let entryRequest = DeedEntryMO.fetchRequest()
            let entries = try context.fetch(entryRequest)
            entries.forEach(context.delete)

            let cardRequest = DeedCardMO.fetchRequest()
            let cards = try context.fetch(cardRequest)
            cards.forEach(context.delete)

            if context.hasChanges {
                try context.save()
            }
        }
    }

    private func randomTimestamp(in range: (start: Date, end: Date)) -> Date {
        let interval = max(1, range.end.timeIntervalSince(range.start))
        let offset = TimeInterval.random(in: 0..<interval)
        return range.start.addingTimeInterval(offset)
    }

    private func randomAmount(for card: DeedCard) -> Double {
        switch card.unitType {
        case .boolean:
            return 1
        case .rating:
            return Double(Int.random(in: 1...5))
        case .count:
            return Double(Int.random(in: 1...4))
        case .duration:
            let minutes = Int.random(in: 2...24) * 5
            return Double(minutes)
        case .quantity:
            if card.polarity == .positive {
                return Double(Int.random(in: 1...8) * 250)
            } else {
                return Double(Int.random(in: 1...3))
            }
        }
    }
}
