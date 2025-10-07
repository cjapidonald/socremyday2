import CoreData
import Foundation

struct DataMaintenanceService {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    init(persistenceController: PersistenceController = .shared) {
        self.init(context: persistenceController.viewContext)
    }

    func resetAllData() throws {
        try clearExistingData()
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
}
