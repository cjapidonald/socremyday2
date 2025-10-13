import CoreData
import Dispatch
import Foundation

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    var viewContext: NSManagedObjectContext { container.viewContext }

    init(inMemory: Bool = false) {
        let model = Self.buildModel()
        container = NSPersistentCloudKitContainer(name: "ScoreMyDay", managedObjectModel: model)

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("###\(#function): Failed to retrieve a persistent store description.")
        }
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: CloudKitEnv.containerID
        )

        let loadSemaphore = DispatchSemaphore(value: 0)
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                assertionFailure("Unresolved Core Data error: \(error), userInfo: \(error.userInfo)")
            }
            loadSemaphore.signal()
        }
        loadSemaphore.wait()
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        do {
            try ensureAppPrefsExists()
        } catch {
            assertionFailure("Failed to prepare persistent store: \(error)")
        }
    }

    private static func buildModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let deedCard = NSEntityDescription()
        deedCard.name = "DeedCard"
        deedCard.managedObjectClassName = NSStringFromClass(DeedCardMO.self)
        deedCard.setCloudKitRecordType("DeedCard")

        let deedEntry = NSEntityDescription()
        deedEntry.name = "DeedEntry"
        deedEntry.managedObjectClassName = NSStringFromClass(DeedEntryMO.self)
        deedEntry.setCloudKitRecordType("DeedEntry")

        let appPrefs = NSEntityDescription()
        appPrefs.name = "AppPrefs"
        appPrefs.managedObjectClassName = NSStringFromClass(AppPrefsMO.self)
        appPrefs.setCloudKitRecordType("AppPrefs")

        deedCard.properties = [
            attribute(name: "idRaw", type: .stringAttributeType, optional: true, cloudKitFieldName: "id"),
            attribute(name: "name", type: .stringAttributeType, defaultValue: "", cloudKitFieldName: "name"),
            attribute(name: "emoji", type: .stringAttributeType, defaultValue: "", cloudKitFieldName: "emoji"),
            attribute(name: "colorHex", type: .stringAttributeType, defaultValue: "", cloudKitFieldName: "colorHex"),
            attribute(name: "category", type: .stringAttributeType, defaultValue: "", cloudKitFieldName: "category"),
            attribute(name: "polarityRaw", type: .integer16AttributeType, defaultValue: 0, cloudKitFieldName: "polarityRaw"),
            attribute(name: "unitTypeRaw", type: .integer16AttributeType, defaultValue: 0, cloudKitFieldName: "unitTypeRaw"),
            attribute(name: "unitLabel", type: .stringAttributeType, defaultValue: "", cloudKitFieldName: "unitLabel"),
            attribute(name: "pointsPerUnit", type: .doubleAttributeType, defaultValue: 0.0, cloudKitFieldName: "pointsPerUnit"),
            attribute(name: "dailyCap", type: .doubleAttributeType, optional: true, cloudKitFieldName: "dailyCap"),
            attribute(name: "isPrivate", type: .booleanAttributeType, defaultValue: false, cloudKitFieldName: "isPrivate"),
            attribute(name: "showOnStats", type: .booleanAttributeType, defaultValue: true, cloudKitFieldName: "showOnStats"),
            attribute(name: "createdAt", type: .dateAttributeType, defaultValue: Date(), cloudKitFieldName: "createdAt"),
            attribute(name: "isArchived", type: .booleanAttributeType, defaultValue: false, cloudKitFieldName: "isArchived"),
            attribute(name: "sortOrder", type: .integer32AttributeType, defaultValue: -1, cloudKitFieldName: "sortOrder")
        ]

        deedEntry.properties = [
            attribute(name: "idRaw", type: .stringAttributeType, optional: true, cloudKitFieldName: "id"),
            attribute(name: "deedIdRaw", type: .stringAttributeType, optional: true, cloudKitFieldName: "deedId"),
            attribute(name: "timestamp", type: .dateAttributeType, defaultValue: Date(), cloudKitFieldName: "timestamp"),
            attribute(name: "amount", type: .doubleAttributeType, defaultValue: 0.0, cloudKitFieldName: "amount"),
            attribute(name: "computedPoints", type: .doubleAttributeType, defaultValue: 0.0, cloudKitFieldName: "computedPoints"),
            attribute(name: "note", type: .stringAttributeType, optional: true, cloudKitFieldName: "note")
        ]

        appPrefs.properties = [
            attribute(name: "idRaw", type: .stringAttributeType, optional: true, cloudKitFieldName: "id"),
            attribute(name: "dayCutoffHour", type: .integer16AttributeType, defaultValue: 4, cloudKitFieldName: "dayCutoffHour"),
            attribute(name: "hapticsOn", type: .booleanAttributeType, defaultValue: true, cloudKitFieldName: "hapticsOn"),
            attribute(name: "soundsOn", type: .booleanAttributeType, defaultValue: true, cloudKitFieldName: "soundsOn"),
            attribute(name: "themeAccent", type: .stringAttributeType, optional: true, cloudKitFieldName: "themeAccent"),
            attribute(name: "themeStyleRaw", type: .stringAttributeType, defaultValue: "dark", cloudKitFieldName: "themeStyleRaw")
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
        entryToCard.minCount = 0
        entryToCard.maxCount = 1
        entryToCard.isOptional = true
        entryToCard.isOrdered = false

        cardToEntries.setCloudKitFieldName("entries")
        entryToCard.setCloudKitFieldName("deed")

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
        defaultValue: Any? = nil,
        cloudKitFieldName: String? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        attribute.allowsExternalBinaryDataStorage = allowsExternalBinaryData
        attribute.defaultValue = defaultValue
        let fieldName = cloudKitFieldName ?? name
        attribute.setCloudKitFieldName(fieldName)
        return attribute
    }

    private func ensureAppPrefsExists() throws {
        let context = viewContext
        try context.performAndReturn {
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
                prefs.themeStyleRaw = AppTheme.dark.rawValue
                if context.hasChanges {
                    try context.save()
                }
            }
        }
    }

}

private extension NSEntityDescription {
    func setCloudKitRecordType(_ recordType: String) {
        var info = userInfo ?? [:]
        info["com.apple.coredata.cloudkit.recordType"] = recordType
        userInfo = info
    }
}

private extension NSPropertyDescription {
    func setCloudKitFieldName(_ fieldName: String) {
        var info = userInfo ?? [:]
        info["com.apple.coredata.cloudkit.fieldName"] = fieldName
        userInfo = info
    }
}
