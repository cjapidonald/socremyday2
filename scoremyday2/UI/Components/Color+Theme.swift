import SwiftUI

extension Color {
    /// Primary neon green accent used throughout the Fitness-inspired theme.
    static let themeMotionGreen = Color(hex: "#29E41F", fallback: .green)

    /// Vibrant purple accent for secondary highlights.
    static let themePulsePurple = Color(hex: "#DB00FF", fallback: .purple)

    /// Bright blue accent for tertiary highlights.
    static let themeChargeBlue = Color(hex: "#00A5EF", fallback: .blue)

    /// Standard background color for dark, high-contrast surfaces.
    static let themeBackground = Color(hex: "#001F3F", fallback: .blue)

    /// Primary foreground color when overlaying on the dark background.
    static let themePrimaryText = Color.white
}
