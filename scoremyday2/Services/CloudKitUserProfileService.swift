import CloudKit
import Foundation

struct CloudKitUserProfileService {
    private let database: CKDatabase

    init?(containerIdentifier: String? = AppConfiguration.cloudKitContainerIdentifier) {
        guard let identifier = containerIdentifier else {
            return nil
        }
        let container = CKContainer(identifier: identifier)
        database = container.privateCloudDatabase
    }

    func upsertProfile(
        appleUserIdentifier: String,
        firstName: String?,
        lastName: String?,
        email: String?
    ) async throws {
        let recordID = CKRecord.ID(recordName: appleUserIdentifier)
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

        record["appleUserIdentifier"] = appleUserIdentifier as CKRecordValue
        if let firstName {
            record["firstName"] = firstName as CKRecordValue
        }
        if let lastName {
            record["lastName"] = lastName as CKRecordValue
        }
        if let email {
            record["email"] = email as CKRecordValue
        }

        _ = try await database.modifyRecords(saving: [record], deleting: [])
    }
}
