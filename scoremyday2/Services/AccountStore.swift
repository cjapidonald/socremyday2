import Foundation
import Combine

@MainActor
final class AccountStore: ObservableObject {
    struct Account {
        let identifier: String
        let email: String?
    }

    static let shared = AccountStore()

    @Published private(set) var account: Account?

    private let defaults: UserDefaults
    private let identifierKey = "account.appleIdentifier"
    private let emailKey = "account.appleEmail"

    init(userDefaults: UserDefaults = .standard) {
        defaults = userDefaults
        if let identifier = defaults.string(forKey: identifierKey) {
            let email = defaults.string(forKey: emailKey)
            account = Account(identifier: identifier, email: email)
        }
    }

    var displayName: String? {
        account?.email ?? account?.identifier
    }

    func update(identifier: String, email: String?) {
        account = Account(identifier: identifier, email: email ?? account?.email)
        defaults.set(identifier, forKey: identifierKey)
        if let email = email ?? account?.email {
            defaults.set(email, forKey: emailKey)
        } else {
            defaults.removeObject(forKey: emailKey)
        }
    }

    func signOut() {
        account = nil
        defaults.removeObject(forKey: identifierKey)
        defaults.removeObject(forKey: emailKey)
    }
}
