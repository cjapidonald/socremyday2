import CloudKit
import Foundation

struct CloudKitUserProfileService {
    enum ServiceError: Swift.Error {
        case accountUnavailable
    }

    private let container: CKContainer
    private let database: CKDatabase

    init?(containerIdentifier: String? = AppConfiguration.cloudKitContainerIdentifier) {
        guard let identifier = containerIdentifier else {
            return nil
        }
        let container = CKContainer(identifier: identifier)
        self.container = container
        database = container.privateCloudDatabase
    }

    func upsertProfile(
        appleUserIdentifier: String,
        firstName: String?,
        lastName: String?,
        email: String?
    ) async throws {
        guard try await container.accountStatus() == .available else {
            throw ServiceError.accountUnavailable
        }

        let recordID = try await container.userRecordID()
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch {
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                record = CKRecord(recordType: "UserProfile", recordID: recordID)
            } else {
                throw error
            }
        }

        record["appleUserIdentifier"] = appleUserIdentifier as NSString
        record["firstName"] = firstName as NSString?
        record["lastName"] = lastName as NSString?
        record["email"] = email as NSString?

        _ = try await database.modifyRecords(saving: [record], deleting: [])
    }
}
