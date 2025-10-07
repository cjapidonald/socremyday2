import Combine
import Foundation

@MainActor
final class AppPrefsStore: ObservableObject {
    static let shared = AppPrefsStore()

    @Published var dayCutoffHour: Int
    @Published var hapticsOn: Bool
    @Published var soundsOn: Bool
    @Published var accentColorHex: String?

    private let repository: AppPrefsRepository
    private var prefsID: UUID
    private var cancellables: Set<AnyCancellable> = []
    private var isPersisting = false

    init(persistenceController: PersistenceController = .shared) {
        let context = persistenceController.viewContext
        repository = AppPrefsRepository(context: context)

        let storedPrefs = (try? repository.fetch()) ?? AppPrefs()
        prefsID = storedPrefs.id
        dayCutoffHour = storedPrefs.dayCutoffHour
        hapticsOn = storedPrefs.hapticsOn
        soundsOn = storedPrefs.soundsOn
        accentColorHex = storedPrefs.accentColorHex

        bindPersistence()
    }

    private func bindPersistence() {
        $dayCutoffHour
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in self?.persistChanges() }
            .store(in: &cancellables)

        $hapticsOn
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in self?.persistChanges() }
            .store(in: &cancellables)

        $soundsOn
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in self?.persistChanges() }
            .store(in: &cancellables)

        $accentColorHex
            .dropFirst()
            .removeDuplicates(by: { $0 == $1 })
            .sink { [weak self] _ in self?.persistChanges() }
            .store(in: &cancellables)

    }

    private func persistChanges() {
        guard !isPersisting else { return }
        isPersisting = true
        let prefs = AppPrefs(
            id: prefsID,
            dayCutoffHour: dayCutoffHour,
            hapticsOn: hapticsOn,
            soundsOn: soundsOn,
            accentColorHex: accentColorHex
        )
        do {
            try repository.update(prefs)
        } catch {
            print("Failed to persist app prefs: \(error)")
        }
        isPersisting = false
    }
}
