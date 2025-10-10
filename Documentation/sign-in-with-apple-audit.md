# Sign in with Apple Capability Audit

This document records the current project configuration relevant to the Sign in with Apple
integration and captures additional manual verification steps that should be performed in Xcode.

## Capability & Entitlements Checklist

- **Sign in with Apple capability** – Enabled at the target level via the `CODE_SIGN_ENTITLEMENTS`
  build setting referencing the app entitlements file.
  - `CODE_SIGN_ENTITLEMENTS = scoremyday2/scoremyday2.entitlements`
  - Ensure the capability remains toggled on in Xcode's *Signing & Capabilities* tab when
    opening the project.
- **Entitlement value** – The entitlements plist contains the required
  `com.apple.developer.applesignin = Default` entry alongside existing iCloud entitlements:
  - `scoremyday2/scoremyday2.entitlements`
- **Bundle identifier** – `com.Donald.scoremyday2` is declared for both Debug and Release build
  configurations. Confirm that this identifier matches the App ID configured with
  Sign in with Apple in the Apple Developer portal.

## Flow-specific reminders

- `fullName` and `email` are provided **only** the first time the authorization succeeds. Persist
  them securely if they are needed later and avoid treating them as mandatory fields on subsequent
  logins.
- When a user chooses **Hide My Email**, any outgoing email must be sent from a domain verified for
  Apple's private email relay to avoid bounce handling being misinterpreted as login failures.

## Implementation validation tips

- Always test Sign in with Apple on a physical iOS device that is signed in to iCloud.
- Provide a valid `presentationContextProvider` when configuring `ASAuthorizationController` to
  avoid generic authorization failures.
- Handle each `ASAuthorizationError` case distinctly (e.g., `canceled` vs `failed`) to give users
  actionable feedback and to aid debugging.
- The `AccountStore` pushes `UserProfile` updates to CloudKit after a successful sign in, so
  network failures should surface a user-facing error message for retrying.

Keep this checklist close when updating signing, provisioning profiles, or onboarding new team
members to the Sign in with Apple flow.

## One-time project setup checklist

1. **Apple Developer portal**
   - Create or select the correct App ID (bundle identifier).
   - Enable the **Sign in with Apple** capability for that App ID.
2. **Xcode target configuration**
   - In *Signing & Capabilities*, add the **Sign in with Apple** capability so that
     `com.apple.developer.applesignin` appears in the entitlements file.
   - Confirm the target uses the same bundle identifier you configured in the developer portal.
3. **Framework linkage**
   - Import `AuthenticationServices` (Xcode generally links it automatically).

## SwiftUI integration snippet

Embed the following SwiftUI helper and button wherever the Sign in with Apple experience belongs in
the app. The manager prepares the request, captures the nonce, and handles the authorization
callback so you can forward tokens to your backend.

```swift
import SwiftUI
import AuthenticationServices
import CryptoKit

@MainActor
final class AppleAuthManager: ObservableObject {
    @Published private(set) var rawNonce: String = ""

    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        let nonce = Self.randomNonce()
        rawNonce = nonce
        request.nonce = Self.sha256(nonce)
    }

    func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }

            let userID = credential.user
            let email = credential.email
            let fullName = credential.fullName
            let idTokenData = credential.identityToken
            let authCodeData = credential.authorizationCode

            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
                // handle .authorized / .revoked / .notFound / .transferred
            }
        case .failure(let error):
            print("Apple Sign-In failed:", error)
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            precondition(status == errSecSuccess, "Unable to generate nonce.")
            for random in randoms {
                if remaining == 0 { break }
                if random < charset.count {
                    result.append(charset[Int(random % UInt8(charset.count))])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

struct AppleSignInButtonView: View {
    @StateObject private var auth = AppleAuthManager()

    var body: some View {
        SignInWithAppleButton(.signIn,
                              onRequest: auth.prepare,
                              onCompletion: auth.handle)
            .signInWithAppleButtonStyle(.black)
            .frame(height: 48)
            .padding()
    }
}
```

## Server-side verification reminders

- Fetch Apple's public keys from `https://appleid.apple.com/auth/keys` to validate the JWT signature.
- Verify the token issuer (`iss`), audience (`aud` equals your bundle/service ID), expiration, and
  your nonce to prevent replay.
- For web or REST flows, exchange the authorization code for tokens using Apple's REST API.

## UX and Human Interface Guidelines

- Use Apple's provided `SignInWithAppleButton` without custom styling beyond the documented
  variants.
- Display the button as prominently as other federated sign-in providers.

## Production-readiness checklist

- Securely store `credential.user` (e.g., in the Keychain) and persist `email`/`fullName` after the
  first authorization—they will be `nil` on subsequent logins.
- Hash and send the nonce alongside the token to your backend and validate it server-side.
- Observe `ASAuthorizationAppleIDProvider.credentialRevokedNotification` or periodically check
  credential state to handle revocations gracefully.
- Define how local sign-out interacts with any backend session revocation.
- Confirm capabilities are enabled in both the Apple Developer portal and the Xcode target, and that
  bundle IDs/team IDs match what the backend expects when validating the token audience.

## Testing scenarios

- Exercise flows on real devices signed in to an Apple ID with two-factor authentication enabled.
- Test both **Share My Email** and **Hide My Email** paths; note that private relay emails are unique
  per app.
- To simulate a first-time authorization, delete the app and remove it from *Settings → Apple ID →
  Passwords & Security → Apps Using Apple ID* before re-testing.
- If the backend participates in verification, capture and inspect the identity token during QA.

## Troubleshooting quick reference

- If the button appears but no sheet is presented, ensure the capability/entitlement is enabled and
  that the device is signed in with an Apple ID that has 2FA.
- `fullName`/`email` returning `nil` after the first authorization is expected—use the stored values
  instead of treating it as a failure.
- Persistent `.revoked` results are common on simulators; confirm behavior on a physical device
  before diagnosing further.
