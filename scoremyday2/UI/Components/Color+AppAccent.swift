import SwiftUI

extension Color {
    init(_ accentIdentifier: String) {
        switch accentIdentifier {
        case "sunrise":
            self = Color.orange
        case "twilight":
            self = Color.purple
        default:
            self = Color.accentColor
        }
    }
}
