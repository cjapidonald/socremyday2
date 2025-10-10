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

    static let shared = AccountStore()

    @Published private(set) var account: Account?

    private let defaults: UserDefaults
    private let userProfileService: CloudKitUserProfileService?
    private let identifierKey = "account.appleIdentifier"
    private let emailKey = "account.appleEmail"
    private let nameKey = "account.appleName"

    init(
        userDefaults: UserDefaults = .standard,
        userProfileService: CloudKitUserProfileService? = CloudKitUserProfileService()
    ) {
        defaults = userDefaults
        self.userProfileService = userProfileService
        if let identifier = defaults.string(forKey: identifierKey) {
            let email = defaults.string(forKey: emailKey)
            let name = defaults.string(forKey: nameKey)
            account = Account(identifier: identifier, email: email, name: name)
        }
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

    func handleSignIn(credential: ASAuthorizationAppleIDCredential) async throws {
        let identifier = credential.user
        let email = credential.email ?? account?.email

        let fullNameFormatter = PersonNameComponentsFormatter()
        let fullName = credential.fullName
            .flatMap { fullNameFormatter.string(from: $0) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }

        update(identifier: identifier, email: email, name: fullName)

        guard let userProfileService else { return }

        let firstName = credential.fullName?.givenName
        let lastName = credential.fullName?.familyName
        try await userProfileService.upsertProfile(
            appleUserIdentifier: identifier,
            firstName: firstName,
            lastName: lastName,
            email: email
        )
    }
}
