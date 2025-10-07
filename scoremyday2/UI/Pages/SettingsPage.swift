import SwiftUI

struct SettingsPage: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment

    var body: some View {
        NavigationStack {
            List {
                Section("Preferences") {
                    Toggle("Haptics", isOn: Binding(
                        get: { appEnvironment.settings.hapticsEnabled },
                        set: { newValue in
                            var updated = appEnvironment.settings
                            updated.hapticsEnabled = newValue
                            appEnvironment.settings = updated
                        }
                    ))

                    Toggle("Sounds", isOn: Binding(
                        get: { appEnvironment.settings.soundsEnabled },
                        set: { newValue in
                            var updated = appEnvironment.settings
                            updated.soundsEnabled = newValue
                            appEnvironment.settings = updated
                        }
                    ))
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsPage()
        .environmentObject(AppEnvironment())
}
