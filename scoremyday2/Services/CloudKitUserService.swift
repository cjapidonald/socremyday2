import CloudKit
import Foundation

struct CloudKitUserService {
    enum ServiceError: Swift.Error, LocalizedError {
        case accountUnavailable
        case cloudKit(CKError)

        var errorDescription: String? {
            switch self {
            case .accountUnavailable:
                return "Please sign into iCloud to continue."
            case .cloudKit(let error):
                switch error.code {
                case .permissionFailure:
                    return "iCloud does not have permission to access ScoreMyDay data."
                case .notAuthenticated:
                    return "Please sign into iCloud to continue."
                case .unknownItem:
                    return "We couldn’t find your ScoreMyDay profile. Please try again."
                default:
                    return error.localizedDescription
                }
            }
        }
    }

    private let container: CKContainer
    private let database: CKDatabase
    private let analytics: AnalyticsProviding

    init(
        container: CKContainer = .default(),
        analytics: AnalyticsProviding = AnalyticsEngine.shared
    ) {
        self.container = container
        self.database = container.publicCloudDatabase
        self.analytics = analytics
    }

    func upsertUserProfile(
        appleID: String,
        email: String?,
        firstName: String?,
        lastName: String?
    ) async throws {
        guard try await container.accountStatus() == .available else {
            throw ServiceError.accountUnavailable
        }

        let predicate = NSPredicate(format: "appleUserIdentifier == %@", appleID)
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)

        let record: CKRecord
        do {
            let (matchResults, _) = try await database.records(
                matching: query,
                desiredKeys: ["appleUserIdentifier", "email", "firstName", "lastName"],
                resultsLimit: 1
            )
            if let (_, result) = matchResults.first {
                switch result {
                case .success(let existingRecord):
                    record = existingRecord
                case .failure(let error):
                    throw mapError(error)
                }
            } else {
                record = CKRecord(recordType: "UserProfile")
                record["appleUserIdentifier"] = appleID as NSString
            }
        } catch {
            throw mapError(error)
        }

        if record.object(forKey: "appleUserIdentifier") == nil {
            record["appleUserIdentifier"] = appleID as NSString
        }
        if let email {
            record["email"] = email as NSString
        }
        if let firstName {
            record["firstName"] = firstName as NSString
        }
        if let lastName {
            record["lastName"] = lastName as NSString
        }

        do {
            _ = try await database.modifyRecords(saving: [record], deleting: [])
        } catch {
            throw mapError(error)
        }
    }

    private func mapError(_ error: Error) -> Error {
        if let ckError = error as? CKError {
            analytics.track(event: AnalyticsEvent(
                name: "cloudkit_user_profile_error",
                metadata: [
                    "code": String(ckError.code.rawValue),
                    "reason": String(describing: ckError.code),
                    "domain": CKError.errorDomain
                ]
            ))
            return ServiceError.cloudKit(ckError)
        }
        return error
    }
}
