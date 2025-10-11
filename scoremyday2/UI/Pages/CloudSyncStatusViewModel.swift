import CloudKit
import Combine
import CoreData
import Foundation

@MainActor
final class CloudSyncStatusViewModel: ObservableObject {
    struct DisplayState: Equatable {
        var statusText: String
        var lastSuccessText: String?
        var errorText: String?
    }

    @Published private(set) var displayState = DisplayState(
        statusText: "Preparing iCloud sync…",
        lastSuccessText: nil,
        errorText: nil
    )

    private let container: NSPersistentCloudKitContainer
    private let relativeFormatter: RelativeDateTimeFormatter
    private let absoluteFormatter: DateFormatter
    private var eventObserver: NSObjectProtocol?
    private var accountChangeObserver: NSObjectProtocol?

    private var accountStatus: CKAccountStatus?
    private var isSyncInProgress = false
    private var lastSuccessfulSync: Date?
    private var lastError: Error?

    init(container: NSPersistentCloudKitContainer) {
        self.container = container
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .full
        relativeFormatter = relative

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = false
        absoluteFormatter = formatter

        observeContainerEvents()
        observeAccountChanges()
        refreshAccountStatus()
    }

    convenience init() {
        self.init(container: PersistenceController.shared.container)
    }

    deinit {
        if let eventObserver {
            NotificationCenter.default.removeObserver(eventObserver)
        }
        if let accountChangeObserver {
            NotificationCenter.default.removeObserver(accountChangeObserver)
        }
    }

    private func observeContainerEvents() {
        eventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: container,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
                return
            }
            Task { @MainActor [weak self] in
                self?.handle(event: event)
            }
        }
    }

    private func observeAccountChanges() {
        accountChangeObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAccountStatus()
            }
        }
    }

    private func refreshAccountStatus() {
        Task {
            do {
                let status = try await CloudKitEnv.container.accountStatus()
                await MainActor.run {
                    self.accountStatus = status
                    self.updateDisplay()
                }
            } catch {
                await MainActor.run {
                    self.accountStatus = nil
                    self.lastError = error
                    self.updateDisplay()
                }
            }
        }
    }

    private func handle(event: NSPersistentCloudKitContainer.Event) {
        if event.endDate == nil {
            isSyncInProgress = true
        } else {
            isSyncInProgress = false
            if let error = event.error {
                lastError = error
            } else if let endDate = event.endDate {
                if let current = lastSuccessfulSync {
                    lastSuccessfulSync = max(current, endDate)
                } else {
                    lastSuccessfulSync = endDate
                }
                lastError = nil
            } else {
                lastSuccessfulSync = lastSuccessfulSync ?? Date()
                lastError = nil
            }
        }

        updateDisplay()
    }

    private func updateDisplay() {
        var statusText: String
        var lastSuccessText: String?
        var errorText: String?

        if isSyncInProgress {
            statusText = "Syncing with iCloud…"
        } else {
            switch accountStatus {
            case .some(.available):
                if let lastSuccessfulSync {
                    let relative = relativeFormatter.localizedString(for: lastSuccessfulSync, relativeTo: Date())
                    let absolute = absoluteFormatter.string(from: lastSuccessfulSync)
                    statusText = "iCloud sync up to date"
                    lastSuccessText = "Last successful sync \(relative) (\(absolute))"
                } else {
                    statusText = "Waiting for first successful sync"
                }
            case .some(.noAccount):
                statusText = "Sign in to iCloud to enable sync"
            case .some(.restricted):
                statusText = "iCloud account is restricted"
            case .some(.temporarilyUnavailable):
                statusText = "iCloud is temporarily unavailable"
            case .some(.couldNotDetermine):
                statusText = "Could not determine iCloud status"
            case .none:
                statusText = "Preparing iCloud sync…"
            @unknown default:
                statusText = "iCloud status unavailable"
            }
        }

        if let error = lastError {
            errorText = error.localizedDescription
        }

        let newState = DisplayState(
            statusText: statusText,
            lastSuccessText: lastSuccessText,
            errorText: errorText
        )

        if newState != displayState {
            displayState = newState
        }
    }
}
