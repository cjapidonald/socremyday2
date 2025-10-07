import CoreData
import Foundation

struct EntryCreationRequest {
    var deedId: UUID
    var timestamp: Date
    var amount: Double
    var note: String?
}

final class EntriesRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func logEntry(_ request: EntryCreationRequest, cutoffHour: Int) throws -> DeedEntry {
        try context.performAndReturn {
            guard let deed = try context.fetchDeedCard(id: request.deedId) else {
                throw NSError(domain: "EntriesRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Deed not found"])
            }

            let rawAmount = request.amount
            let rawPoints = rawAmount * deed.pointsPerUnit
            let computedPoints: Double
            if let cap = deed.dailyCap?.doubleValue, cap >= 0, rawPoints > 0 {
                let dayRange = appDayRange(for: request.timestamp, cutoffHour: cutoffHour)
                let existingAmount = try amountCountedTowardCap(for: deed, within: dayRange)
                let remainingAmount = max(0, cap - existingAmount)
                let amountAwarded = max(0, min(rawAmount, remainingAmount))
                computedPoints = amountAwarded * deed.pointsPerUnit
            } else {
                computedPoints = rawPoints
            }

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

            return DeedEntry(managedObject: entry)
        }
    }

    func fetchEntries(forDeed id: UUID? = nil, in range: ClosedRange<Date>? = nil) throws -> [DeedEntry] {
        try context.performAndReturn {
            let request = DeedEntryMO.fetchRequest()
            var predicates: [NSPredicate] = []
            if let id {
                predicates.append(NSPredicate(format: "deedId == %@", id as CVarArg))
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
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            guard let entry = try context.fetch(request).first else { return }
            context.delete(entry)
            if context.hasChanges {
                try context.save()
            }
        }
    }

    private func amountCountedTowardCap(
        for deed: DeedCardMO,
        within range: (start: Date, end: Date)
    ) throws -> Double {
        let request = DeedEntryMO.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "deed == %@", deed),
            NSPredicate(format: "timestamp >= %@ AND timestamp < %@", range.start as NSDate, range.end as NSDate)
        ])
        let entries = try context.fetch(request)
        return entries.reduce(0) { partialResult, entry in
            guard entry.computedPoints > 0 else { return partialResult }
            return partialResult + max(0, entry.amount)
        }
    }
}
