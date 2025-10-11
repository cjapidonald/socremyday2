import UIKit

final class HapticsManager {
    static let shared = HapticsManager()
    private init() {}

    /// Flip these to real prefs in your app (see AppPrefsStore below)
    private var hapticsOn: Bool { AppPrefsStore.shared.hapticsOn }

    /// Positive log: notification .success then a soft impact .light
    func positive() {
        guard hapticsOn else { return }
        let notif = UINotificationFeedbackGenerator()
        notif.prepare()
        notif.notificationOccurred(.success)

        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.prepare()
        impact.impactOccurred()
    }

    /// Negative log: notification .warning, then a slightly stronger .medium impact
    func negative() {
        guard hapticsOn else { return }
        let notif = UINotificationFeedbackGenerator()
        notif.prepare()
        notif.notificationOccurred(.warning) // or .error if you prefer

        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()
        impact.impactOccurred()
    }

    /// Light tap feedback for simple interactions such as tapping a card
    func cardTap() {
        guard hapticsOn else { return }
        let impact = UIImpactFeedbackGenerator(style: .soft)
        impact.prepare()
        impact.impactOccurred(intensity: 0.6)
    }
}
