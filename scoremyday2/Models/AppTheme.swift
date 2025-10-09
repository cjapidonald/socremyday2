import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable, Equatable {
    case dark
    case light

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark:
            return "Dark"
        case .light:
            return "Light"
        }
    }

    var preferredColorScheme: ColorScheme {
        switch self {
        case .dark:
            return .dark
        case .light:
            return .light
        }
    }

    var backgroundColor: Color {
        switch self {
        case .dark:
            return .black
        case .light:
            return .white
        }
    }

    var primaryTextColor: Color {
        switch self {
        case .dark:
            return .white
        case .light:
            return .black
        }
    }

    var invertedTextColor: Color {
        switch self {
        case .dark:
            return .black
        case .light:
            return .white
        }
    }
}
