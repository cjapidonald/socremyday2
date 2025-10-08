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
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(DeedCardMO.createdAt), ascending: true)]
            let objects = try context.fetch(request)
            return objects.map(DeedCard.init(managedObject:))
        }
    }

    func get(id: UUID) throws -> DeedCard? {
        try context.performAndReturn {
            try context.fetchDeedCard(id: id).map(DeedCard.init(managedObject:))
        }
    }

    func upsert(_ card: DeedCard) throws {
        try context.performAndWait {
            let object = try context.fetchDeedCard(id: card.id) ?? DeedCardMO(context: context)
            object.update(from: card)
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
}
