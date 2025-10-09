import CoreData

@objc(DeedCardMO)
final class DeedCardMO: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var emoji: String
    @NSManaged var colorHex: String
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
}

extension DeedCardMO {
    @nonobjc class func fetchRequest() -> NSFetchRequest<DeedCardMO> {
        NSFetchRequest<DeedCardMO>(entityName: "DeedCard")
    }
}

@objc(DeedEntryMO)
final class DeedEntryMO: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var deedId: UUID
    @NSManaged var timestamp: Date
    @NSManaged var amount: Double
    @NSManaged var computedPoints: Double
    @NSManaged var note: String?
    @NSManaged var deed: DeedCardMO
}

extension DeedEntryMO {
    @nonobjc class func fetchRequest() -> NSFetchRequest<DeedEntryMO> {
        NSFetchRequest<DeedEntryMO>(entityName: "DeedEntry")
    }
}

@objc(AppPrefsMO)
final class AppPrefsMO: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var dayCutoffHour: Int16
    @NSManaged var hapticsOn: Bool
    @NSManaged var soundsOn: Bool
    @NSManaged var themeAccent: String?
    @NSManaged var themeStyleRaw: String
}

extension AppPrefsMO {
    @nonobjc class func fetchRequest() -> NSFetchRequest<AppPrefsMO> {
        NSFetchRequest<AppPrefsMO>(entityName: "AppPrefs")
    }
}
