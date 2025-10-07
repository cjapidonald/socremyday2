import Combine

/// Replace this with your real AppPrefs Core Data binding. This stub unblocks compilation.
final class AppPrefsStore: ObservableObject {
    static let shared = AppPrefsStore()
    @Published var hapticsOn: Bool = true
    @Published var soundsOn: Bool = true
}
