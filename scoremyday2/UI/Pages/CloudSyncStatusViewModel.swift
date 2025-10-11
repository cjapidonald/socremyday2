import CloudKit
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

    private var accountStatus: CKAccountStatus?
    private var isSyncInProgress = false
    private var lastSuccessfulSync: Date?
    private var lastError: Error?

    init(container: NSPersistentCloudKitContainer = PersistenceController.shared.container) {
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
        refreshAccountStatus()
    }

    deinit {
        if let eventObserver {
            NotificationCenter.default.removeObserver(eventObserver)
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
            self?.handle(event: event)
        }
    }

    private func refreshAccountStatus() {
        container.accountStatus { [weak self] status, error in
            guard let self else { return }
            Task { @MainActor in
                self.accountStatus = status
                if let error {
                    self.lastError = error
                }
                self.updateDisplay()
            }
        }
    }

    private func handle(event: NSPersistentCloudKitContainer.Event) {
        if event.endDate == nil {
            isSyncInProgress = true
        } else {
            isSyncInProgress = false
            switch event.result {
            case .success?:
                if let endDate = event.endDate {
                    if let current = lastSuccessfulSync {
                        lastSuccessfulSync = max(current, endDate)
                    } else {
                        lastSuccessfulSync = endDate
                    }
                } else {
                    lastSuccessfulSync = lastSuccessfulSync ?? Date()
                }
                lastError = nil
            case .failure(let error)?:
                lastError = error
            case nil:
                break
            @unknown default:
                break
            }
        }

        if #available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *) {
            if event.type == .accountChange {
                refreshAccountStatus()
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
