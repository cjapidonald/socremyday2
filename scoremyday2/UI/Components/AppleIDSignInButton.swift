import AuthenticationServices
import SwiftUI
import UIKit

struct AppleIDSignInButton: UIViewRepresentable {
    typealias UIViewType = ASAuthorizationAppleIDButton

    var type: ASAuthorizationAppleIDButton.ButtonType = .signIn
    var style: ASAuthorizationAppleIDButton.Style = .black
    var cornerRadius: CGFloat = 6
    var preflightCheck: (() async throws -> Void)?
    var prepareAppleRequest: (ASAuthorizationAppleIDRequest) -> Void
    var completion: (Result<ASAuthorization, Error>) -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: type, style: style)
        button.cornerRadius = cornerRadius
        button.addTarget(context.coordinator, action: #selector(Coordinator.didTapButton), for: .touchUpInside)
        context.coordinator.updateAnchorSource(with: button)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        uiView.cornerRadius = cornerRadius
        context.coordinator.updateAnchorSource(with: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        private let parent: AppleIDSignInButton
        private var controller: ASAuthorizationController?
        private weak var anchorButton: ASAuthorizationAppleIDButton?

        init(parent: AppleIDSignInButton) {
            self.parent = parent
        }

        func updateAnchorSource(with button: ASAuthorizationAppleIDButton) {
            anchorButton = button
        }

        @objc
        func didTapButton() {
            Task { @MainActor in
                do {
                    if let preflight = parent.preflightCheck {
                        try await preflight()
                    }
                } catch {
                    parent.completion(.failure(error))
                    return
                }

                let provider = ASAuthorizationAppleIDProvider()
                let request = provider.createRequest()
                parent.prepareAppleRequest(request)

                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = self
                controller.presentationContextProvider = self
                self.controller = controller
                controller.performRequests()
            }
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            Task { @MainActor in
                self.parent.completion(.success(authorization))
                self.controller = nil
            }
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            Task { @MainActor in
                self.parent.completion(.failure(error))
                self.controller = nil
            }
        }

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            if let window = anchorButton?.window {
                return window
            }

            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }

            // Prefer an existing key window if available
            if let keyWindow = scenes
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }) {
                return keyWindow
            }

            // Attempt to locate any active scene to bind a window to
            if let activeScene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first {
                if let window = activeScene.windows.first {
                    return window
                }
                if #available(iOS 26.0, *) {
                    return UIWindow(windowScene: activeScene)
                } else {
                    return UIWindow(frame: .zero)
                }
            }

            // As a final fallback, return any existing window we can create within the current deployment target.
            if #available(iOS 26.0, *) {
                assertionFailure("Unable to locate a UIWindowScene for Sign in with Apple presentation")
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                    fatalError("A UIWindowScene is required to present the authorization controller.")
                }
                return UIWindow(windowScene: scene)
            } else {
                return UIWindow(frame: .zero)
            }
        }
    }
}
