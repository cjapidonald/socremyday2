import SwiftUI

struct SettingsPage: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @State private var isLoadingDemoData = false
    @State private var demoDataError: String?

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

                Section("QA") {
                    Toggle(isOn: Binding(
                        get: { false },
                        set: { newValue in
                            guard newValue else { return }
                            loadDemoData()
                        }
                    )) {
                        HStack {
                            Text("Load Demo Data")
                            if isLoadingDemoData {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isLoadingDemoData)
                }
            }
            .navigationTitle("Settings")
            .alert("Unable to Load Demo Data", isPresented: Binding(
                get: { demoDataError != nil },
                set: { isPresented in
                    if !isPresented {
                        demoDataError = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(demoDataError ?? "")
            }
        }
    }

    private func loadDemoData() {
        guard !isLoadingDemoData else { return }
        isLoadingDemoData = true

        Task { @MainActor in
            defer { isLoadingDemoData = false }

            do {
                let service = DemoDataService(persistenceController: appEnvironment.persistenceController)
                try service.loadDemoData()
            } catch {
                demoDataError = error.localizedDescription
            }
        }
    }
}

#Preview {
    SettingsPage()
        .environmentObject(AppEnvironment())
}
