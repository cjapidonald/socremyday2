import Foundation
import Combine

@MainActor
final class AppEnvironment: ObservableObject {
    @Published var settings = AppSettings()
    @Published var selectedTab: RootTab = .deeds
    @Published var dataVersion: Int = 0
    let persistenceController: PersistenceController
    private let prefsStore: AppPrefsStore
    private var cancellables: Set<AnyCancellable> = []

    init(persistenceController: PersistenceController, prefsStore: AppPrefsStore) {
        self.persistenceController = persistenceController
        self.prefsStore = prefsStore

        var updated = settings
        updated.dayCutoffHour = prefsStore.dayCutoffHour
        updated.hapticsEnabled = prefsStore.hapticsOn
        updated.soundsEnabled = prefsStore.soundsOn
        updated.accentColorHex = prefsStore.accentColorHex
        settings = updated

        prefsStore.$hapticsOn
            .removeDuplicates()
            .sink { [weak self] value in
                guard let self else { return }
                guard self.settings.hapticsEnabled != value else { return }
                var current = self.settings
                current.hapticsEnabled = value
                self.settings = current
            }
            .store(in: &cancellables)

        prefsStore.$soundsOn
            .removeDuplicates()
            .sink { [weak self] value in
                guard let self else { return }
                guard self.settings.soundsEnabled != value else { return }
                var current = self.settings
                current.soundsEnabled = value
                self.settings = current
            }
            .store(in: &cancellables)

        prefsStore.$dayCutoffHour
            .removeDuplicates()
            .sink { [weak self] value in
                guard let self else { return }
                guard self.settings.dayCutoffHour != value else { return }
                var current = self.settings
                current.dayCutoffHour = value
                self.settings = current
            }
            .store(in: &cancellables)

        prefsStore.$accentColorHex
            .removeDuplicates(by: { $0 == $1 })
            .sink { [weak self] value in
                guard let self else { return }
                guard self.settings.accentColorHex != value else { return }
                var current = self.settings
                current.accentColorHex = value
                self.settings = current
            }
            .store(in: &cancellables)

    }

    convenience init(persistenceController: PersistenceController = .shared) {
        self.init(persistenceController: persistenceController, prefsStore: .shared)
    }

    func notifyDataDidChange() {
        dataVersion &+= 1
    }
}
