import AuthenticationServices
import Combine
import Foundation

@MainActor
final class AccountStore: ObservableObject {
    struct Account {
        let identifier: String
        let email: String?
        let name: String?
    }

    @MainActor static let shared = AccountStore()

    @Published private(set) var account: Account?

    private let defaults: UserDefaults
    private let userService: CloudKitUserService?
    private let keychain: KeychainStore
    private let identifierKey = "account.appleIdentifier"
    private let emailKey = "account.appleEmail"
    private let nameKey = "account.appleName"
    private let hasSeenNameEmailKey = "account.hasSeenAppleNameEmail"

    private(set) var hasSeenAppleNameEmail = false

    init(
        userDefaults: UserDefaults = .standard,
        userService: CloudKitUserService? = nil,
        keychain: KeychainStore? = nil
    ) {
        defaults = userDefaults
        self.userService = userService ?? CloudKitUserService()
        self.keychain = keychain ?? KeychainStore()

        if let identifier = (try? self.keychain.string(forKey: identifierKey)) ?? defaults.string(forKey: identifierKey) {
            let email = defaults.string(forKey: emailKey)
            let name = defaults.string(forKey: nameKey)
            account = Account(identifier: identifier, email: email, name: name)
        }

        hasSeenAppleNameEmail = (try? self.keychain.bool(forKey: hasSeenNameEmailKey)) ?? false
    }

    var displayName: String? {
        account?.name ?? account?.email ?? account?.identifier
    }

    private func update(identifier: String, email: String?, name: String?) {
        account = Account(
            identifier: identifier,
            email: email ?? account?.email,
            name: name ?? account?.name
        )
        do {
            try keychain.set(identifier, forKey: identifierKey)
        } catch {
            #if DEBUG
            print("Failed to persist Apple ID: \(error)")
            #endif
        }
        defaults.removeObject(forKey: identifierKey)
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
        do {
            try keychain.removeValue(forKey: identifierKey)
            try keychain.removeValue(forKey: hasSeenNameEmailKey)
        } catch {
            #if DEBUG
            print("Failed to clear Keychain: \(error)")
            #endif
        }
        hasSeenAppleNameEmail = false
    }

    func handleSignIn(credential: ASAuthorizationAppleIDCredential) async throws {
        let identifier = credential.user
        let email = credential.email ?? account?.email

        let fullNameFormatter = PersonNameComponentsFormatter()
        let fullName = credential.fullName
            .flatMap { fullNameFormatter.string(from: $0) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }

        update(identifier: identifier, email: email, name: fullName)

        if !hasSeenAppleNameEmail {
            hasSeenAppleNameEmail = true
            do {
                try keychain.set(true, forKey: hasSeenNameEmailKey)
            } catch {
                #if DEBUG
                print("Failed to mark Apple name/email prompt as seen: \(error)")
                #endif
            }
        }

        guard let userService else { return }

        let firstName = credential.fullName?.givenName
        let lastName = credential.fullName?.familyName
        try await userService.upsertUserProfile(
            appleID: identifier,
            email: email,
            firstName: firstName,
            lastName: lastName
        )
    }

    func shouldRequestNameAndEmail() -> Bool {
        !hasSeenAppleNameEmail
    }
}
