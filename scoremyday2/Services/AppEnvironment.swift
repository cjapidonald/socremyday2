import Foundation
import Combine

final class AppEnvironment: ObservableObject {
    @Published var settings = AppSettings()
    let persistenceController: PersistenceController
    private var cancellables: Set<AnyCancellable> = []

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController

        let prefs = AppPrefsStore.shared
        var updated = settings
        updated.hapticsEnabled = prefs.hapticsOn
        updated.soundsEnabled = prefs.soundsOn
        settings = updated

        prefs.$hapticsOn
            .removeDuplicates()
            .sink { [weak self] value in
                guard let self else { return }
                guard self.settings.hapticsEnabled != value else { return }
                var current = self.settings
                current.hapticsEnabled = value
                self.settings = current
            }
            .store(in: &cancellables)

        prefs.$soundsOn
            .removeDuplicates()
            .sink { [weak self] value in
                guard let self else { return }
                guard self.settings.soundsEnabled != value else { return }
                var current = self.settings
                current.soundsEnabled = value
                self.settings = current
            }
            .store(in: &cancellables)
    }
}
