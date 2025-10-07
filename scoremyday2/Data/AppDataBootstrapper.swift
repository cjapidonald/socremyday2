import Foundation

enum AppDataBootstrapper {
    static func performInitialLoadIfNeeded() {
        UserDefaults.standard.register(defaults: [
            "ScoreMyDay.initialized": true
        ])
    }
}
