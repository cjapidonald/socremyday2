import AuthenticationServices
import CloudKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsPage: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @ObservedObject private var prefs = AppPrefsStore.shared
    @ObservedObject private var accountStore = AccountStore.shared

    @State private var dayCutoffSelection = SettingsPage.makeDate(forHour: AppPrefsStore.shared.dayCutoffHour, minute: AppPrefsStore.shared.dayCutoffMinute)
    @State private var isResettingData = false
    @State private var showResetConfirmation = false
    @State private var actionError: String?
    @State private var jsonExportDocument: FolderExportDocument?
    @State private var csvExportDocument: FolderExportDocument?
    @State private var isPresentingJSONExporter = false
    @State private var isPresentingCSVExporter = false
    @State private var isPreparingJSONExport = false
    @State private var isPreparingCSVExport = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false

    private let shareURL = URL(string: "https://apps.apple.com/vn/app/forge-the-better-me/id6753785275?l=en")!

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
                let newDate = SettingsPage.makeDate(forHour: newValue, minute: prefs.dayCutoffMinute)
                let calendar = Calendar.current
                if calendar.component(.hour, from: dayCutoffSelection) != newValue ||
                   calendar.component(.minute, from: dayCutoffSelection) != prefs.dayCutoffMinute {
                    dayCutoffSelection = newDate
                }
            }
            .onChange(of: prefs.dayCutoffMinute) { _, newValue in
                let newDate = SettingsPage.makeDate(forHour: prefs.dayCutoffHour, minute: newValue)
                let calendar = Calendar.current
                if calendar.component(.hour, from: dayCutoffSelection) != prefs.dayCutoffHour ||
                   calendar.component(.minute, from: dayCutoffSelection) != newValue {
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
            .confirmationDialog(
                "Delete Account?",
                isPresented: $showDeleteAccountConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    Task {
                        await performAccountDeletion()
                    }
                }
            } message: {
                Text("Deleting your account removes your profile and all synced data from iCloud. This action cannot be undone.")
            }
            .fileExporter(
                isPresented: $isPresentingJSONExporter,
                document: jsonExportDocument,
                contentType: .folder,
                defaultFilename: "Forge-JSON-Export"
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
                defaultFilename: "Forge-CSV-Export"
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
            if let account = accountStore.account {
                let welcomeText = account.name ?? account.email ?? "Welcome"

                VStack(alignment: .leading, spacing: 6) {
                    Label(welcomeText, systemImage: "applelogo")
                        .font(.headline)
                }
                .padding(.vertical, 4)

                Button("Sign Out", role: .destructive) {
                    accountStore.signOut()
                }
                .disabled(isDeletingAccount)

                Button(role: .destructive) {
                    showDeleteAccountConfirmation = true
                } label: {
                    HStack {
                        Label("Delete Account", systemImage: "person.crop.circle.badge.xmark")
                        Spacer()
                        if isDeletingAccount {
                            ProgressView()
                        }
                    }
                }
                .disabled(isDeletingAccount)
            } else {
                Label("Welcome", systemImage: "applelogo")
                    .font(.headline)

                AppleIDSignInButton(
                    type: .signIn,
                    style: .black,
                    preflightCheck: ensureICloudAccountAvailable,
                    prepareAppleRequest: { request in
                        if accountStore.shouldRequestNameAndEmail() {
                            request.requestedScopes = [.fullName, .email]
                        } else {
                            request.requestedScopes = []
                        }
                    },
                    completion: { result in
                        switch result {
                        case .success(let authorization):
                            handleAppleAuthorization(authorization)
                        case .failure(let error):
                            handleAppleAuthorizationFailure(error)
                        }
                    }
                )
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

            Toggle("Haptics & Vibration", isOn: $prefs.hapticsOn)
            Toggle("Sounds", isOn: $prefs.soundsOn)

            VStack(alignment: .leading, spacing: 8) {
                Text("Appearance")
                    .font(.subheadline.weight(.semibold))
                Picker("Theme", selection: $prefs.theme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName)
                            .tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.top, 4)

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
                subject: Text("Forge"),
                message: Text("I’ve been tracking my deeds with Forge. Check it out!")
            ) {
                Label("Share Forge", systemImage: "square.and.arrow.up")
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
        let theme = appEnvironment.settings.theme
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
                                    .foregroundStyle(theme.primaryTextColor.opacity(0.9))
                            }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if option.isSelected(with: prefs.accentColorHex) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(theme.primaryTextColor)
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

        Task {
            do {
                try await accountStore.handleSignIn(credential: credential)
            } catch {
                await MainActor.run {
                    actionError = error.localizedDescription
                }
            }
        }
    }

    private func handleAppleAuthorizationFailure(_ error: Error) {
        if let preflightError = error as? SignInPreflightError {
            actionError = preflightError.localizedDescription
            return
        }

        if let authorizationError = error as? ASAuthorizationError {
            // Handle specific codes by comparing raw values without directly referencing cases that may not exist on older SDKs
            // credentialRevoked was introduced in iOS 15. Compare raw values only when building against iOS 15+.
            if #available(iOS 15.0, *), authorizationError.code.rawValue == 5 /* ASAuthorizationError.Code.credentialRevoked */ {
                actionError = "Your Apple ID credentials have been revoked. Please sign in again."
                return
            }

            // appLaunchProhibited was introduced in iOS 17. Compare raw values only when building against iOS 17+.
            if #available(iOS 17.0, *), authorizationError.code.rawValue == 6 /* ASAuthorizationError.Code.appLaunchProhibited */ {
                actionError = "Sign in with Apple could not launch the required app. Please try again later."
                return
            }

            // Fall back to handling the rest of the known cases
            switch authorizationError.code {
            case .canceled:
                return
            case .failed, .invalidResponse, .notHandled:
                actionError = "Sign in with Apple could not be completed. Please try again."
                return
            default:
                // Covers .unknown, .notInteractive and any future cases on older SDKs
                actionError = "Sign in with Apple is unavailable right now. Please try again later."
                return
            }
        }

        if let localized = (error as? LocalizedError)?.errorDescription, !localized.isEmpty {
            actionError = localized
            return
        }

        actionError = error.localizedDescription
    }

    private enum SignInPreflightError: LocalizedError {
        case iCloudUnavailable

        var errorDescription: String? {
            "Please sign into iCloud to continue."
        }
    }

    @MainActor
    private func ensureICloudAccountAvailable() async throws {
        let status = try await CloudKitEnv.container.accountStatus()
        if status != .available {
            actionError = "Please sign into iCloud to continue."
            throw SignInPreflightError.iCloudUnavailable
        }
    }

    private func handleDayCutoffSelectionChange(previous: Date, newValue: Date) {
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
        let minute = calendar.component(.minute, from: date)

        if prefs.dayCutoffHour != hour {
            prefs.dayCutoffHour = hour
        }
        if prefs.dayCutoffMinute != minute {
            prefs.dayCutoffMinute = minute
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

    @MainActor
    private func performAccountDeletion() async {
        showDeleteAccountConfirmation = false
        guard !isDeletingAccount else { return }
        isDeletingAccount = true

        do {
            try await accountStore.deleteAccount()
            appEnvironment.notifyDataDidChange()
        } catch {
            actionError = error.localizedDescription
        }

        isDeletingAccount = false
    }

    private func resetAllData() {
        guard !isResettingData else { return }
        let storedPrefs = (
            dayCutoffHour: prefs.dayCutoffHour,
            dayCutoffMinute: prefs.dayCutoffMinute,
            hapticsOn: prefs.hapticsOn,
            soundsOn: prefs.soundsOn,
            accentColorHex: prefs.accentColorHex,
            theme: prefs.theme
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
                    if prefs.dayCutoffMinute != storedPrefs.dayCutoffMinute {
                        prefs.dayCutoffMinute = storedPrefs.dayCutoffMinute
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
                    if prefs.theme != storedPrefs.theme {
                        prefs.theme = storedPrefs.theme
                    }
                    dayCutoffSelection = SettingsPage.makeDate(forHour: storedPrefs.dayCutoffHour, minute: storedPrefs.dayCutoffMinute)
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

    private static func makeDate(forHour hour: Int, minute: Int = 0) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
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
