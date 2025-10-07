import SwiftUI

struct SettingsPage: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @ObservedObject private var prefs = AppPrefsStore.shared
    @State private var isLoadingDemoData = false
    @State private var demoDataError: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Preferences") {
                    Toggle("Haptics", isOn: $prefs.hapticsOn)
                    Toggle("Sounds", isOn: $prefs.soundsOn)
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
            .onAppear {
                SoundManager.shared.preload()
            }
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
