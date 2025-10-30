import SwiftUI

@main
struct ForgeApp: App {
    @StateObject private var appEnvironment = AppEnvironment()

    init() {
        SoundManager.shared.preload()
        AppDataBootstrapper.performInitialLoadIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appEnvironment)
        }
    }
}
