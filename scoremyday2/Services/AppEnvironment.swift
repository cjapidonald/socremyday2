import Combine
import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let iconSystemName: String?

        init(message: String, iconSystemName: String? = nil) {
            self.message = message
            self.iconSystemName = iconSystemName
        }
    }

    @Published var settings = AppSettings()
    @Published var selectedTab: RootTab = .deeds
    @Published var dataVersion: Int = 0
    @Published var toast: Toast?
    let persistenceController: PersistenceController
    private var cancellables: Set<AnyCancellable> = []
    private var toastDismissTask: Task<Void, Never>?

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController

        let prefs = AppPrefsStore.shared
        var updated = settings
        updated.dayCutoffHour = prefs.dayCutoffHour
        updated.hapticsEnabled = prefs.hapticsOn
        updated.soundsEnabled = prefs.soundsOn
        updated.accentColorHex = prefs.accentColorHex
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
    }

    deinit {
        toastDismissTask?.cancel()
    }

    func notifyDataDidChange() {
        dataVersion &+= 1
    }

    func showToast(
        message: String,
        iconSystemName: String? = nil,
        duration: TimeInterval = 2.5
    ) {
        toastDismissTask?.cancel()
        toastDismissTask = nil

        let newToast = Toast(message: message, iconSystemName: iconSystemName)
        toast = newToast

        guard duration > 0 else { return }

        let nanoseconds = UInt64(max(0, duration) * 1_000_000_000)
        toastDismissTask = Task { [weak self] in
            guard nanoseconds > 0 else { return }
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                if self.toast?.id == newToast.id {
                    self.toast = nil
                }
            }
        }
    }

    func hideToast(matching toastID: Toast.ID? = nil) {
        guard let current = toast else { return }
        if let toastID, toastID != current.id {
            return
        }

        toastDismissTask?.cancel()
        toastDismissTask = nil
        toast = nil
    }
}
