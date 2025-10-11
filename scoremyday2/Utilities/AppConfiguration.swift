import Foundation

enum AppConfiguration {
    private static let defaultCloudKitContainerIdentifier = "iCloud.com.Donald.matrix"

    static var cloudKitContainerIdentifier: String? {
        if let rawValue = Bundle.main.object(forInfoDictionaryKey: "CloudKitContainerIdentifier") as? String {
            let identifier = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !identifier.isEmpty {
                return identifier
            }
        }

        return defaultCloudKitContainerIdentifier
    }
}
