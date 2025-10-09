import CoreData
import Foundation

@MainActor
final class DeedsRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchAll(includeArchived: Bool = false) throws -> [DeedCard] {
        return try context.performAndReturn {
            let request = DeedCardMO.fetchRequest()
            if !includeArchived {
                request.predicate = NSPredicate(format: "isArchived == NO")
            }
            request.sortDescriptors = [
                NSSortDescriptor(key: #keyPath(DeedCardMO.sortOrder), ascending: true),
                NSSortDescriptor(key: #keyPath(DeedCardMO.createdAt), ascending: true)
            ]
            let objects = try context.fetch(request)

            var needsSave = false
            for (index, object) in objects.enumerated() where object.sortOrder < 0 {
                object.sortOrder = Int32(index)
                needsSave = true
            }

            if needsSave, context.hasChanges {
                try context.save()
            }

            return objects
                .sorted { lhs, rhs in
                    if lhs.sortOrder == rhs.sortOrder {
                        if lhs.createdAt == rhs.createdAt {
                            return lhs.id.uuidString < rhs.id.uuidString
                        }
                        return lhs.createdAt < rhs.createdAt
                    }
                    return lhs.sortOrder < rhs.sortOrder
                }
                .map(DeedCard.init(managedObject:))
        }
    }

    func get(id: UUID) throws -> DeedCard? {
        try context.performAndReturn {
            try context.fetchDeedCard(id: id).map(DeedCard.init(managedObject:))
        }
    }

    func upsert(_ card: DeedCard) throws {
        try context.performAndWait {
            var updatedCard = card
            if let existing = try context.fetchDeedCard(id: card.id) {
                existing.update(from: updatedCard)
            } else {
                let object = DeedCardMO(context: context)
                if updatedCard.sortOrder < 0 {
                    // Inline fetch of max sortOrder to avoid cross-actor call
                    let request = DeedCardMO.fetchRequest()
                    request.sortDescriptors = [NSSortDescriptor(key: #keyPath(DeedCardMO.sortOrder), ascending: false)]
                    request.fetchLimit = 1
                    let result = try context.fetch(request)
                    let next = (result.first?.sortOrder ?? -1) + 1
                    updatedCard.sortOrder = Int(next)
                }
                object.update(from: updatedCard)
            }
            if context.hasChanges {
                try context.save()
            }
        }
    }

    func delete(id: UUID) throws {
        try context.performAndWait {
            guard let object = try context.fetchDeedCard(id: id) else { return }
            context.delete(object)
            if context.hasChanges {
                try context.save()
            }
        }
    }

    func updateSortOrders(_ cards: [DeedCard]) throws {
        guard !cards.isEmpty else { return }
        try context.performAndWait {
            for card in cards {
                guard let object = try context.fetchDeedCard(id: card.id) else { continue }
                object.sortOrder = Int32(card.sortOrder)
            }
            if context.hasChanges {
                try context.save()
            }
        }
    }
}
