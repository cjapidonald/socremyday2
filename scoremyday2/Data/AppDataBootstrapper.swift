import Foundation
import CoreData

enum AppDataBootstrapper {
    static func performInitialLoadIfNeeded() {
        UserDefaults.standard.register(defaults: [
            "ScoreMyDay.initialized": true
        ])

        // Clear all demo cards on first launch after this update
        if !UserDefaults.standard.bool(forKey: "ScoreMyDay.demoCardsCleared") {
            clearAllCards()
            UserDefaults.standard.set(true, forKey: "ScoreMyDay.demoCardsCleared")
        }
    }

    private static func clearAllCards() {
        let controller = PersistenceController.shared
        let context = controller.viewContext

        let request = DeedCardMO.fetchRequest()

        do {
            let cards = try context.fetch(request)
            for card in cards {
                context.delete(card)
            }
            if context.hasChanges {
                try context.save()
            }
        } catch {
            print("Failed to clear demo cards: \(error)")
        }
    }
}
