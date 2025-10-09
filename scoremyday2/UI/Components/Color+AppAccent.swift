import SwiftUI

extension Color {
    init(_ accentIdentifier: String) {
        switch accentIdentifier {
        case "pulse":
            self = .themePulsePurple
        case "charge":
            self = .themeChargeBlue
        case "sunrise":
            self = Color(hex: "#FF9F0A", fallback: .orange)
        case "forest":
            self = Color(hex: "#34C759", fallback: .green)
        case "lavender":
            self = Color(hex: "#AF52DE", fallback: .purple)
        case "rose":
            self = Color(hex: "#FF375F", fallback: .pink)
        default:
            self = .themeMotionGreen
        }
    }
}
