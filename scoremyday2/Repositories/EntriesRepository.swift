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

            let rawPoints = request.amount * deed.pointsPerUnit
            let computedPoints: Double
            let wasCapped: Bool
            if let capAmount = deed.dailyCap?.doubleValue,
               capAmount >= 0,
               rawPoints > 0,
               deed.pointsPerUnit > 0
            {
                let dayRange = appDayRange(for: request.timestamp, cutoffHour: cutoffHour)
                let existingPoints = try pointsAwarded(for: deed, within: dayRange, positiveOnly: true)
                let existingAmount = existingPoints / deed.pointsPerUnit
                let remainingAmount = max(0, capAmount - existingAmount)
                let awardedAmount = max(0, min(request.amount, remainingAmount))
                computedPoints = awardedAmount * deed.pointsPerUnit
                wasCapped = awardedAmount < request.amount
            } else {
                computedPoints = rawPoints
                wasCapped = false
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

            let model = DeedEntry(managedObject: entry)
            return LogEntryResult(entry: model, wasCapped: wasCapped)
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

    private func pointsAwarded(
        for deed: DeedCardMO,
        within range: (start: Date, end: Date),
        positiveOnly: Bool
    ) throws -> Double {
        let request = DeedEntryMO.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "deed == %@", deed),
            NSPredicate(format: "timestamp >= %@ AND timestamp < %@", range.start as NSDate, range.end as NSDate)
        ])
        let entries = try context.fetch(request)
        return entries.reduce(0) { partialResult, entry in
            let value = entry.computedPoints
            if positiveOnly {
                return partialResult + max(0, value)
            } else {
                return partialResult + value
            }
        }
    }
}
