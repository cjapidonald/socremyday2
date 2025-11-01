import CoreData
import Foundation

struct EntryCreationRequest {
    var deedId: UUID
    var timestamp: Date
    var amount: Double
    var note: String?
}

struct LogEntryResult {
    let entry: DeedEntry
    let wasCapped: Bool
}

@MainActor
final class EntriesRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func logEntry(_ request: EntryCreationRequest, cutoffHour: Int) throws -> LogEntryResult {
        try context.performAndReturn {
            guard let deed = try context.fetchDeedCard(id: request.deedId) else {
                throw NSError(domain: "EntriesRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Deed not found"])
            }

            // IMPORTANT: Points per tap should be fixed, not multiplied by amount!
            // The amount is for tracking purposes (money, time, count) only.
            // Each tap always gives the same points regardless of amount.
            let computedPoints = deed.pointsPerUnit
            let wasCapped = false

            // Debug logging
            print("🔍 ENTRY CALCULATION:")
            print("   Deed: \(deed.name)")
            print("   Amount logged: \(request.amount) \(deed.unitLabel)")
            print("   Points awarded: \(computedPoints)")
            print("   (Points are NOT multiplied by amount)")

            let entry = DeedEntryMO(context: context)
            entry.id = UUID()
            entry.deed = deed
            entry.deedId = deed.id
            entry.timestamp = request.timestamp
            entry.amount = request.amount
            entry.computedPoints = computedPoints
            entry.note = request.note

            if context.hasChanges {
                try context.save()
            }

            let model = DeedEntry(managedObject: entry)
            return LogEntryResult(entry: model, wasCapped: wasCapped)
        }
    }

    func fetchEntries(forDeed id: UUID? = nil, in range: ClosedRange<Date>? = nil) throws -> [DeedEntry] {
        try context.performAndReturn {
            let request = DeedEntryMO.fetchRequest()
            var predicates: [NSPredicate] = []
            if let id {
                predicates.append(NSPredicate(format: "deedIdRaw == %@", id.uuidString))
            }
            if let range {
                predicates.append(NSPredicate(format: "timestamp >= %@ AND timestamp <= %@", range.lowerBound as NSDate, range.upperBound as NSDate))
            }
            if !predicates.isEmpty {
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            }
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(DeedEntryMO.timestamp), ascending: true)]
            let entries = try context.fetch(request)
            return entries.map(DeedEntry.init(managedObject:))
        }
    }

    func deleteEntry(id: UUID) throws {
        try context.performAndWait {
            let request = DeedEntryMO.fetchRequest()
            request.predicate = NSPredicate(format: "idRaw == %@", id.uuidString)
            request.fetchLimit = 1
            guard let entry = try context.fetch(request).first else { return }
            context.delete(entry)
            if context.hasChanges {
                try context.save()
            }
        }
    }

}
