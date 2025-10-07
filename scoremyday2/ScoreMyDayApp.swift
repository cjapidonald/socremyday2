import SwiftUI

@main
struct ScoreMyDayApp: App {
    @StateObject private var appEnvironment = AppEnvironment()

    init() {
        SoundManager.shared.preload()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appEnvironment)
        }
    }
}
