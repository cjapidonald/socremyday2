import CoreData
import Foundation

extension DeedCard {
    init(managedObject: DeedCardMO) {
        self.init(
            id: managedObject.id,
            name: managedObject.name,
            emoji: managedObject.emoji,
            colorHex: managedObject.colorHex,
            category: managedObject.category,
            polarity: Polarity(rawValue: managedObject.polarityRaw) ?? .positive,
            unitType: UnitType(rawValue: managedObject.unitTypeRaw) ?? .count,
            unitLabel: managedObject.unitLabel,
            pointsPerUnit: managedObject.pointsPerUnit,
            dailyCap: managedObject.dailyCap?.doubleValue,
            isPrivate: managedObject.isPrivate,
            showOnStats: managedObject.showOnStats,
            createdAt: managedObject.createdAt,
            isArchived: managedObject.isArchived,
            sortOrder: Int(managedObject.sortOrder)
        )
    }
}

extension DeedCardMO {
    func update(from card: DeedCard) {
        id = card.id
        name = card.name
        emoji = card.emoji
        colorHex = card.colorHex
        category = card.category
        polarityRaw = card.polarity.rawValue
        unitTypeRaw = card.unitType.rawValue
        unitLabel = card.unitLabel
        pointsPerUnit = card.pointsPerUnit
        if let cap = card.dailyCap {
            dailyCap = NSNumber(value: cap)
        } else {
            dailyCap = nil
        }
        isPrivate = card.isPrivate
        showOnStats = card.showOnStats
        createdAt = card.createdAt
        isArchived = card.isArchived
        sortOrder = Int32(card.sortOrder)
    }
}

extension DeedEntry {
    init(managedObject: DeedEntryMO) {
        self.init(
            id: managedObject.id,
            deedId: managedObject.deedId,
            timestamp: managedObject.timestamp,
            amount: managedObject.amount,
            computedPoints: managedObject.computedPoints,
            note: managedObject.note
        )
    }
}

extension DeedEntryMO {
    func update(from entry: DeedEntry, context: NSManagedObjectContext) throws {
        id = entry.id
        deedId = entry.deedId
        timestamp = entry.timestamp
        amount = entry.amount
        computedPoints = entry.computedPoints
        note = entry.note
        if let deed = try context.fetchDeedCard(id: entry.deedId) {
            self.deed = deed
        }
    }
}

extension AppPrefs {
    init(managedObject: AppPrefsMO) {
        self.init(
            id: managedObject.id,
            dayCutoffHour: Int(managedObject.dayCutoffHour),
            hapticsOn: managedObject.hapticsOn,
            soundsOn: managedObject.soundsOn,
            accentColorHex: managedObject.themeAccent
        )
    }
}

extension AppPrefsMO {
    func update(from prefs: AppPrefs) {
        id = prefs.id
        dayCutoffHour = Int16(prefs.dayCutoffHour)
        hapticsOn = prefs.hapticsOn
        soundsOn = prefs.soundsOn
        themeAccent = prefs.accentColorHex
    }
}

extension NSManagedObjectContext {
    func fetchDeedCard(id: UUID) throws -> DeedCardMO? {
        let request = DeedCardMO.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        let objects = try fetch(request)
        return objects.first
    }
}
