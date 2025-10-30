import CoreData

@objc(DeedCardMO)
final class DeedCardMO: NSManagedObject {
    @NSManaged private var idRaw: String?
    @NSManaged var name: String
    @NSManaged var emoji: String
    @NSManaged var colorHex: String
    @NSManaged var textColorHex: String
    @NSManaged var category: String
    @NSManaged var polarityRaw: Int16
    @NSManaged var unitTypeRaw: Int16
    @NSManaged var unitLabel: String
    @NSManaged var pointsPerUnit: Double
    @NSManaged var dailyCap: NSNumber?
    @NSManaged var isPrivate: Bool
    @NSManaged var showOnStats: Bool
    @NSManaged var createdAt: Date
    @NSManaged var isArchived: Bool
    @NSManaged var sortOrder: Int32
    @NSManaged var entries: Set<DeedEntryMO>

    var id: UUID {
        get {
            if let idRaw, let uuid = UUID(uuidString: idRaw) {
                return uuid
            }
            let generated = UUID()
            idRaw = generated.uuidString
            return generated
        }
        set {
            idRaw = newValue.uuidString
        }
    }
}

extension DeedCardMO {
    @nonobjc class func fetchRequest() -> NSFetchRequest<DeedCardMO> {
        NSFetchRequest<DeedCardMO>(entityName: "DeedCard")
    }
}

@objc(DeedEntryMO)
final class DeedEntryMO: NSManagedObject {
    @NSManaged private var idRaw: String?
    @NSManaged private var deedIdRaw: String?
    @NSManaged var timestamp: Date
    @NSManaged var amount: Double
    @NSManaged var computedPoints: Double
    @NSManaged var note: String?
    @NSManaged var deed: DeedCardMO

    var id: UUID {
        get {
            if let idRaw, let uuid = UUID(uuidString: idRaw) {
                return uuid
            }
            let generated = UUID()
            idRaw = generated.uuidString
            return generated
        }
        set {
            idRaw = newValue.uuidString
        }
    }

    var deedId: UUID {
        get {
            if let deedIdRaw, let uuid = UUID(uuidString: deedIdRaw) {
                return uuid
            }
            let fallback = deed.id
            deedIdRaw = fallback.uuidString
            return fallback
        }
        set {
            deedIdRaw = newValue.uuidString
        }
    }
}

extension DeedEntryMO {
    @nonobjc class func fetchRequest() -> NSFetchRequest<DeedEntryMO> {
        NSFetchRequest<DeedEntryMO>(entityName: "DeedEntry")
    }
}

@objc(AppPrefsMO)
final class AppPrefsMO: NSManagedObject {
    @NSManaged private var idRaw: String?
    @NSManaged var dayCutoffHour: Int16
    @NSManaged var hapticsOn: Bool
    @NSManaged var soundsOn: Bool
    @NSManaged var themeAccent: String?
    @NSManaged var themeStyleRaw: String

    var id: UUID {
        get {
            if let idRaw, let uuid = UUID(uuidString: idRaw) {
                return uuid
            }
            let generated = UUID()
            idRaw = generated.uuidString
            return generated
        }
        set {
            idRaw = newValue.uuidString
        }
    }
}

extension AppPrefsMO {
    @nonobjc class func fetchRequest() -> NSFetchRequest<AppPrefsMO> {
        NSFetchRequest<AppPrefsMO>(entityName: "AppPrefs")
    }
}
