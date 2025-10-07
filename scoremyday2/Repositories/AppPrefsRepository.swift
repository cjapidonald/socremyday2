import CoreData
import Foundation

final class AppPrefsRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetch() throws -> AppPrefs {
        try context.performAndReturn {
            let request = AppPrefsMO.fetchRequest()
            request.fetchLimit = 1
            if let prefs = try context.fetch(request).first {
                return AppPrefs(managedObject: prefs)
            } else {
                let defaults = AppPrefs()
                let managed = AppPrefsMO(context: context)
                managed.update(from: defaults)
                try context.save()
                return defaults
            }
        }
    }

    func update(_ prefs: AppPrefs) throws {
        try context.performAndWait {
            let request = AppPrefsMO.fetchRequest()
            request.fetchLimit = 1
            let managed = try context.fetch(request).first ?? AppPrefsMO(context: context)
            managed.update(from: prefs)
            if context.hasChanges {
                try context.save()
            }
        }
    }
}
