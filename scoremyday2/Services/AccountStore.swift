import Foundation
import Combine

@MainActor
final class AccountStore: ObservableObject {
    struct Account {
        let identifier: String
        let email: String?
        let name: String?
    }

    static let shared = AccountStore()

    @Published private(set) var account: Account?

    private let defaults: UserDefaults
    private let identifierKey = "account.appleIdentifier"
    private let emailKey = "account.appleEmail"
    private let nameKey = "account.appleName"

    init(userDefaults: UserDefaults = .standard) {
        defaults = userDefaults
        if let identifier = defaults.string(forKey: identifierKey) {
            let email = defaults.string(forKey: emailKey)
            let name = defaults.string(forKey: nameKey)
            account = Account(identifier: identifier, email: email, name: name)
        }
    }

    var displayName: String? {
        account?.name ?? account?.email ?? account?.identifier
    }

    func update(identifier: String, email: String?, name: String?) {
        account = Account(
            identifier: identifier,
            email: email ?? account?.email,
            name: name ?? account?.name
        )
        defaults.set(identifier, forKey: identifierKey)
        if let email = email ?? account?.email {
            defaults.set(email, forKey: emailKey)
        } else {
            defaults.removeObject(forKey: emailKey)
        }
        if let name = name ?? account?.name {
            defaults.set(name, forKey: nameKey)
        } else {
            defaults.removeObject(forKey: nameKey)
        }
    }

    func signOut() {
        account = nil
        defaults.removeObject(forKey: identifierKey)
        defaults.removeObject(forKey: emailKey)
        defaults.removeObject(forKey: nameKey)
    }
}
