import Foundation
import Combine

final class AppEnvironment: ObservableObject {
    @Published var settings = AppSettings()
    let persistenceController: PersistenceController

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
}
