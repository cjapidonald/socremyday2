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

Keep this checklist close when updating signing, provisioning profiles, or onboarding new team
members to the Sign in with Apple flow.
