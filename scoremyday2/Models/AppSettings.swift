import Foundation

struct AppSettings: Equatable {
    var dayCutoffHour: Int = 4
    var hapticsEnabled: Bool = true
    var soundsEnabled: Bool = true
    var accentColorHex: String?
    var theme: AppTheme = .dark
}
