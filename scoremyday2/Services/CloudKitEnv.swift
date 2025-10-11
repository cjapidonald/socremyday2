import CloudKit
import Foundation

enum CloudKitEnv {
    static let containerID: String = {
        if let rawValue = Bundle.main.object(forInfoDictionaryKey: "CloudKitContainerIdentifier") as? String {
            let identifier = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !identifier.isEmpty {
                return identifier
            }
        }

        return "iCloud.com.Donald.matrix"
    }()

    static let container: CKContainer = CKContainer(identifier: containerID)

    static var publicDatabase: CKDatabase { container.publicCloudDatabase }

    static var privateDatabase: CKDatabase { container.privateCloudDatabase }
}
