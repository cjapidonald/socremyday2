import CoreData
import Foundation

struct DemoDataService {
    private let deedsRepository: DeedsRepository
    private let entriesRepository: EntriesRepository
    private let prefsRepository: AppPrefsRepository

    init(context: NSManagedObjectContext) {
        self.deedsRepository = DeedsRepository(context: context)
        self.entriesRepository = EntriesRepository(context: context)
        self.prefsRepository = AppPrefsRepository(context: context)
    }

    init(persistenceController: PersistenceController = .shared) {
        self.init(context: persistenceController.viewContext)
    }

    func populateDemoEntriesIfNeeded() throws {
        let existing = try entriesRepository.fetchEntries()
        guard existing.isEmpty else { return }

        let cards = try deedsRepository.fetchAll(includeArchived: false)
        guard !cards.isEmpty else { return }

        let prefs = try prefsRepository.fetch()
        let cutoff = prefs.dayCutoffHour

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let now = Date()

        for dayOffset in 0..<14 {
            guard let baseDate = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let dayStart = appDayRange(for: baseDate, cutoffHour: cutoff, calendar: calendar).start

            for (index, card) in cards.prefix(3).enumerated() where !card.isPrivate {
                let timestamp = calendar.date(byAdding: .hour, value: 2 + index * 3, to: dayStart) ?? dayStart
                let amount = amountForDemo(index: index, dayOffset: dayOffset, unitType: card.unitType)
                let request = EntryCreationRequest(
                    deedId: card.id,
                    timestamp: timestamp,
                    amount: amount,
                    note: "Demo entry"
                )
                _ = try entriesRepository.logEntry(request, cutoffHour: cutoff)
            }
        }
    }

    private func amountForDemo(index: Int, dayOffset: Int, unitType: UnitType) -> Double {
        let base = Double((index + dayOffset) % 3 + 1)
        switch unitType {
        case .boolean:
            return 1
        case .rating:
            return min(5, base + 2)
        default:
            return base
        }
    }
}
