import Foundation

enum AppConfiguration {
    static var cloudKitContainerIdentifier: String? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: "CloudKitContainerIdentifier") as? String else {
            return nil
        }

        let identifier = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty else {
            return nil
        }

        return identifier
    }
}
