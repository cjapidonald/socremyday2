import Foundation

struct AppSettings: Equatable {
    var dayCutoffHour: Int = 4
    var hapticsEnabled: Bool = true
    var soundsEnabled: Bool = true
    var accentColorIdentifier: String = "default"
}
