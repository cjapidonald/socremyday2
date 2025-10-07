import Foundation
import Combine

@MainActor
final class AppEnvironment: ObservableObject {
    @Published var settings = AppSettings()
    @Published var selectedTab: RootTab = .deeds
    @Published var dataVersion: Int = 0
    let persistenceController: PersistenceController
    private var cancellables: Set<AnyCancellable> = []

    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController

        let prefs = AppPrefsStore.shared
        var updated = settings
        updated.dayCutoffHour = prefs.dayCutoffHour
        updated.hapticsEnabled = prefs.hapticsOn
        updated.soundsEnabled = prefs.soundsOn
        updated.accentColorHex = prefs.accentColorHex
        updated.showSuggestions = prefs.showSuggestions
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

        prefs.$dayCutoffHour
            .removeDuplicates()
            .sink { [weak self] value in
                guard let self else { return }
                guard self.settings.dayCutoffHour != value else { return }
                var current = self.settings
                current.dayCutoffHour = value
                self.settings = current
            }
            .store(in: &cancellables)

        prefs.$accentColorHex
            .removeDuplicates(by: { $0 == $1 })
            .sink { [weak self] value in
                guard let self else { return }
                guard self.settings.accentColorHex != value else { return }
                var current = self.settings
                current.accentColorHex = value
                self.settings = current
            }
            .store(in: &cancellables)

        prefs.$showSuggestions
            .removeDuplicates()
            .sink { [weak self] value in
                guard let self else { return }
                guard self.settings.showSuggestions != value else { return }
                var current = self.settings
                current.showSuggestions = value
                self.settings = current
            }
            .store(in: &cancellables)
    }

    convenience init() {
        self.init(persistenceController: .shared)
    }

    func notifyDataDidChange() {
        dataVersion &+= 1
    }
}
