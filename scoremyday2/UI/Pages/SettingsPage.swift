import AuthenticationServices
import SwiftUI
import UniformTypeIdentifiers

struct SettingsPage: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @ObservedObject private var prefs = AppPrefsStore.shared
    @ObservedObject private var accountStore = AccountStore.shared

    @State private var dayCutoffSelection = SettingsPage.makeDate(forHour: AppPrefsStore.shared.dayCutoffHour)
    @State private var isResettingData = false
    @State private var showResetConfirmation = false
    @State private var actionError: String?
    @State private var jsonExportDocument: FolderExportDocument?
    @State private var csvExportDocument: FolderExportDocument?
    @State private var isPresentingJSONExporter = false
    @State private var isPresentingCSVExporter = false
    @State private var isPreparingJSONExport = false
    @State private var isPreparingCSVExport = false
    @State private var isNormalizingDayCutoff = false

    private let shareURL = URL(string: "https://apps.apple.com/app/id0000000000")!

    var body: some View {
        NavigationStack {
            List {
                accountSection
                preferencesSection
                dataSection
                shareSection
                aboutSection
            }
            .navigationTitle("Settings")
            .onAppear {
                SoundManager.shared.preload()
            }
            .onChange(of: prefs.dayCutoffHour) { _, newValue in
                let newDate = SettingsPage.makeDate(forHour: newValue)
                if Calendar.current.component(.hour, from: dayCutoffSelection) != newValue {
                    dayCutoffSelection = newDate
                }
            }
            .alert("Something went wrong", isPresented: Binding(
                get: { actionError != nil },
                set: { newValue in
                    if !newValue {
                        actionError = nil
                    }
                }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(actionError ?? "")
            }
            .confirmationDialog(
                "Reset All Data?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset All Data", role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("This deletes all deeds and entries. Preferences remain unchanged. This action cannot be undone.")
            }
            .fileExporter(
                isPresented: $isPresentingJSONExporter,
                document: jsonExportDocument,
                contentType: .folder,
                defaultFilename: "ScoreMyDay-JSON-Export"
            ) { result in
                if case .failure(let error) = result {
                    actionError = error.localizedDescription
                }
                jsonExportDocument = nil
            }
            .fileExporter(
                isPresented: $isPresentingCSVExporter,
                document: csvExportDocument,
                contentType: .folder,
                defaultFilename: "ScoreMyDay-CSV-Export"
            ) { result in
                if case .failure(let error) = result {
                    actionError = error.localizedDescription
                }
                csvExportDocument = nil
            }
        }
    }

    private var accountSection: some View {
        Section("Account") {
            if let displayName = accountStore.displayName {
                VStack(alignment: .leading, spacing: 6) {
                    Label(displayName, systemImage: "applelogo")
                        .font(.headline)
                    Text("Sync coming soon.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                Button("Sign Out", role: .destructive) {
                    accountStore.signOut()
                }
            } else {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        handleAppleAuthorization(authorization)
                    case .failure(let error):
                        actionError = error.localizedDescription
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
            }
        }
    }

    private var preferencesSection: some View {
        Section("Preferences") {
            DatePicker(
                "Day Cutoff",
                selection: $dayCutoffSelection,
                displayedComponents: [.hourAndMinute]
            )
            .datePickerStyle(.wheel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: dayCutoffSelection) { previous, newValue in
                handleDayCutoffSelectionChange(previous: previous, newValue: newValue)
            }

            Toggle("Haptics", isOn: $prefs.hapticsOn)
            Toggle("Sounds", isOn: $prefs.soundsOn)

            VStack(alignment: .leading, spacing: 8) {
                Text("Accent Color")
                    .font(.subheadline.weight(.semibold))
                accentPalette
            }
            .padding(.top, 4)
        }
    }

    private var dataSection: some View {
        Section("Data") {
            Button {
                prepareJSONExport()
            } label: {
                HStack {
                    Label("Export JSON", systemImage: "doc.zipper")
                    Spacer()
                    if isPreparingJSONExport {
                        ProgressView()
                    }
                }
            }
            .disabled(isPreparingJSONExport)

            Button {
                prepareCSVExport()
            } label: {
                HStack {
                    Label("Export CSV", systemImage: "tablecells")
                    Spacer()
                    if isPreparingCSVExport {
                        ProgressView()
                    }
                }
            }
            .disabled(isPreparingCSVExport)

            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                HStack {
                    Label("Reset All Data", systemImage: "trash")
                    Spacer()
                    if isResettingData {
                        ProgressView()
                    }
                }
            }
            .disabled(isResettingData)
        }
    }

    private var shareSection: some View {
        Section("Share") {
            ShareLink(
                item: shareURL,
                subject: Text("ScoreMyDay"),
                message: Text("I’ve been tracking my deeds with ScoreMyDay. Check it out!")
            ) {
                Label("Share ScoreMyDay", systemImage: "square.and.arrow.up")
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(Self.versionString)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var accentPalette: some View {
        let columns = [GridItem(.adaptive(minimum: 48, maximum: 64), spacing: 12)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(AccentColorOption.allOptions) { option in
                Button {
                    prefs.accentColorHex = option.hex
                } label: {
                    Circle()
                        .fill(option.color)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .strokeBorder(option.isSelected(with: prefs.accentColorHex) ? Color.primary.opacity(0.8) : .clear, lineWidth: 3)
                        )
                        .overlay {
                            if option.isSystem {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if option.isSelected(with: prefs.accentColorHex) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color.white)
                                    .shadow(radius: 1)
                                    .offset(x: -2, y: -2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.name)
            }
        }
        .padding(.top, 4)
    }

    private func handleAppleAuthorization(_ authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            actionError = "Unable to read Apple ID credentials."
            return
        }

        let identifier = credential.user
        let email = credential.email ?? accountStore.account?.email
        accountStore.update(identifier: identifier, email: email)
    }

    private func handleDayCutoffSelectionChange(previous: Date, newValue: Date) {
        if isNormalizingDayCutoff {
            isNormalizingDayCutoff = false
            return
        }

        playDayCutoffTick(previous: previous, newValue: newValue)
        updateDayCutoff(with: newValue)
    }

    private func playDayCutoffTick(previous: Date, newValue: Date) {
        guard previous != newValue else { return }
        SoundManager.shared.positive()
    }

    private func updateDayCutoff(with date: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let hour = calendar.component(.hour, from: date)
        if prefs.dayCutoffHour != hour {
            prefs.dayCutoffHour = hour
        }

        if calendar.component(.minute, from: date) != 0 || calendar.component(.second, from: date) != 0 {
            if let normalized = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) {
                isNormalizingDayCutoff = true
                dayCutoffSelection = normalized
            }
        }
    }

    private func prepareJSONExport() {
        guard !isPreparingJSONExport else { return }
        isPreparingJSONExport = true
        do {
            let service = DataExportService(persistenceController: appEnvironment.persistenceController)
            let files = try service.makeJSONExport()
            jsonExportDocument = FolderExportDocument(items: files)
            isPresentingJSONExporter = true
        } catch {
            actionError = error.localizedDescription
        }
        isPreparingJSONExport = false
    }

    private func prepareCSVExport() {
        guard !isPreparingCSVExport else { return }
        isPreparingCSVExport = true
        do {
            let service = DataExportService(persistenceController: appEnvironment.persistenceController)
            let files = try service.makeCSVExport()
            csvExportDocument = FolderExportDocument(items: files)
            isPresentingCSVExporter = true
        } catch {
            actionError = error.localizedDescription
        }
        isPreparingCSVExport = false
    }

    private func resetAllData() {
        guard !isResettingData else { return }
        let storedPrefs = (
            dayCutoffHour: prefs.dayCutoffHour,
            hapticsOn: prefs.hapticsOn,
            soundsOn: prefs.soundsOn,
            accentColorHex: prefs.accentColorHex
        )
        isResettingData = true

        Task {
            do {
                let service = DataMaintenanceService(persistenceController: appEnvironment.persistenceController)
                try service.resetAllData()
                await MainActor.run {
                    if prefs.dayCutoffHour != storedPrefs.dayCutoffHour {
                        prefs.dayCutoffHour = storedPrefs.dayCutoffHour
                    }
                    if prefs.hapticsOn != storedPrefs.hapticsOn {
                        prefs.hapticsOn = storedPrefs.hapticsOn
                    }
                    if prefs.soundsOn != storedPrefs.soundsOn {
                        prefs.soundsOn = storedPrefs.soundsOn
                    }
                    if prefs.accentColorHex != storedPrefs.accentColorHex {
                        prefs.accentColorHex = storedPrefs.accentColorHex
                    }
                    dayCutoffSelection = SettingsPage.makeDate(forHour: storedPrefs.dayCutoffHour)
                    isResettingData = false
                    appEnvironment.notifyDataDidChange()
                }
            } catch {
                await MainActor.run {
                    isResettingData = false
                    actionError = error.localizedDescription
                }
            }
        }
    }

    private static func makeDate(forHour hour: Int) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = 0
        return calendar.date(from: components) ?? now
    }

    private static var versionString: String {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
        return "\(version) (\(build))"
    }
}

private struct AccentColorOption: Identifiable {
    let id: String
    let name: String
    let hex: String?

    var color: Color {
        if let hex { return Color(hex: hex, fallback: .accentColor) }
        return .accentColor
    }

    var isSystem: Bool { hex == nil }

    func isSelected(with currentHex: String?) -> Bool {
        currentHex == hex
    }

    static let allOptions: [AccentColorOption] = [
        AccentColorOption(id: "system", name: "Motion Green (Default)", hex: nil),
        AccentColorOption(id: "pulse", name: "Pulse Purple", hex: "#DB00FF"),
        AccentColorOption(id: "charge", name: "Charge Blue", hex: "#00A5EF"),
        AccentColorOption(id: "sunrise", name: "Sunrise", hex: "#FF9F0A"),
        AccentColorOption(id: "ocean", name: "Ocean", hex: "#0A84FF"),
        AccentColorOption(id: "forest", name: "Forest", hex: "#34C759"),
        AccentColorOption(id: "lavender", name: "Lavender", hex: "#AF52DE"),
        AccentColorOption(id: "rose", name: "Rose", hex: "#FF375F")
    ]
}

#Preview {
    SettingsPage()
        .environmentObject(AppEnvironment())
}
