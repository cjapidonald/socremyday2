import SwiftUI

extension Color {
    init(hex: String, fallback: Color = .gray) {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        guard Scanner(string: sanitized).scanHexInt64(&value) else {
            self = fallback
            return
        }

        let r, g, b, a: Double
        switch sanitized.count {
        case 3:
            r = Double((value >> 8) & 0xF) / 15.0
            g = Double((value >> 4) & 0xF) / 15.0
            b = Double(value & 0xF) / 15.0
            a = 1
        case 6:
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8) & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
            a = 1
        case 8:
            r = Double((value >> 24) & 0xFF) / 255.0
            g = Double((value >> 16) & 0xFF) / 255.0
            b = Double((value >> 8) & 0xFF) / 255.0
            a = Double(value & 0xFF) / 255.0
        default:
            self = fallback
            return
        }

        self = Color(red: r, green: g, blue: b, opacity: a)
    }
}
