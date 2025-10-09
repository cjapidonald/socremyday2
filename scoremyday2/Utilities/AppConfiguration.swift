import Foundation

enum AppConfiguration {
    private static let placeholderIdentifier = "iCloud.com.example.deedstracker"

    static var cloudKitContainerIdentifier: String? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: "CloudKitContainerIdentifier") as? String else {
            return nil
        }

        let identifier = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty, identifier != placeholderIdentifier else {
            return nil
        }

        return identifier
    }
}
