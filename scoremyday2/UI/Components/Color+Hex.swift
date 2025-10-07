import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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

    func toHex(includeAlpha: Bool = false) -> String? {
        #if canImport(UIKit)
        let platformColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard platformColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        #elseif canImport(AppKit)
        let platformColor = NSColor(self)
        guard let converted = platformColor.usingColorSpace(.deviceRGB) else { return nil }
        let r = converted.redComponent
        let g = converted.greenComponent
        let b = converted.blueComponent
        let a = converted.alphaComponent
        #else
        return nil
        #endif

        if includeAlpha {
            return String(
                format: "#%02X%02X%02X%02X",
                Int(round(r * 255)),
                Int(round(g * 255)),
                Int(round(b * 255)),
                Int(round(a * 255))
            )
        } else {
            return String(
                format: "#%02X%02X%02X",
                Int(round(r * 255)),
                Int(round(g * 255)),
                Int(round(b * 255))
            )
        }
    }
}
