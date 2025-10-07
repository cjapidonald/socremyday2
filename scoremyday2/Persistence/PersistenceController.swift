import CoreData
import Foundation

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext { container.viewContext }

    init(inMemory: Bool = false) {
        let model = Self.buildModel()
        container = NSPersistentContainer(name: "ScoreMyDay", managedObjectModel: model)

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error = error {
                assertionFailure("Unresolved Core Data error: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        do {
            try ensureAppPrefsExists()
            try InitialDataSeeder(context: container.viewContext).runIfNeeded()
        } catch {
            assertionFailure("Failed to seed persistent store: \(error)")
        }
    }

    private static func buildModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let deedCard = NSEntityDescription()
        deedCard.name = "DeedCard"
        deedCard.managedObjectClassName = NSStringFromClass(DeedCardMO.self)

        let deedEntry = NSEntityDescription()
        deedEntry.name = "DeedEntry"
        deedEntry.managedObjectClassName = NSStringFromClass(DeedEntryMO.self)

        let appPrefs = NSEntityDescription()
        appPrefs.name = "AppPrefs"
        appPrefs.managedObjectClassName = NSStringFromClass(AppPrefsMO.self)

        deedCard.properties = [
            attribute(name: "id", type: .UUIDAttributeType),
            attribute(name: "name", type: .stringAttributeType),
            attribute(name: "emoji", type: .stringAttributeType),
            attribute(name: "colorHex", type: .stringAttributeType),
            attribute(name: "category", type: .stringAttributeType),
            attribute(name: "polarityRaw", type: .integer16AttributeType),
            attribute(name: "unitTypeRaw", type: .integer16AttributeType),
            attribute(name: "unitLabel", type: .stringAttributeType),
            attribute(name: "pointsPerUnit", type: .doubleAttributeType),
            attribute(name: "dailyCap", type: .doubleAttributeType, optional: true, allowsExternalBinaryData: false),
            attribute(name: "isPrivate", type: .booleanAttributeType),
            attribute(name: "showOnStats", type: .booleanAttributeType, defaultValue: true),
            attribute(name: "createdAt", type: .dateAttributeType),
            attribute(name: "isArchived", type: .booleanAttributeType)
        ]

        deedEntry.properties = [
            attribute(name: "id", type: .UUIDAttributeType),
            attribute(name: "deedId", type: .UUIDAttributeType),
            attribute(name: "timestamp", type: .dateAttributeType),
            attribute(name: "amount", type: .doubleAttributeType),
            attribute(name: "computedPoints", type: .doubleAttributeType),
            attribute(name: "note", type: .stringAttributeType, optional: true)
        ]

        appPrefs.properties = [
            attribute(name: "id", type: .UUIDAttributeType),
            attribute(name: "dayCutoffHour", type: .integer16AttributeType),
            attribute(name: "hapticsOn", type: .booleanAttributeType),
            attribute(name: "soundsOn", type: .booleanAttributeType),
            attribute(name: "themeAccent", type: .stringAttributeType, optional: true)
        ]

        let cardToEntries = NSRelationshipDescription()
        cardToEntries.name = "entries"
        cardToEntries.destinationEntity = deedEntry
        cardToEntries.deleteRule = .cascadeDeleteRule
        cardToEntries.minCount = 0
        cardToEntries.maxCount = 0
        cardToEntries.isOptional = true
        cardToEntries.isOrdered = false

        let entryToCard = NSRelationshipDescription()
        entryToCard.name = "deed"
        entryToCard.destinationEntity = deedCard
        entryToCard.deleteRule = .nullifyDeleteRule
        entryToCard.minCount = 1
        entryToCard.maxCount = 1
        entryToCard.isOptional = false
        entryToCard.isOrdered = false

        cardToEntries.inverseRelationship = entryToCard
        entryToCard.inverseRelationship = cardToEntries

        deedCard.properties.append(cardToEntries)
        deedEntry.properties.append(entryToCard)

        model.entities = [deedCard, deedEntry, appPrefs]
        return model
    }

    private static func attribute(
        name: String,
        type: NSAttributeType,
        optional: Bool = false,
        allowsExternalBinaryData: Bool = false,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        attribute.allowsExternalBinaryDataStorage = allowsExternalBinaryData
        attribute.defaultValue = defaultValue
        return attribute
    }

    private func ensureAppPrefsExists() throws {
        let context = viewContext
        let request = AppPrefsMO.fetchRequest()
        request.fetchLimit = 1
        let count = try context.count(for: request)
        if count == 0 {
            let prefs = AppPrefsMO(context: context)
            prefs.id = UUID()
            prefs.dayCutoffHour = 4
            prefs.hapticsOn = true
            prefs.soundsOn = true
            prefs.themeAccent = nil
            try context.save()
        }
    }

}
