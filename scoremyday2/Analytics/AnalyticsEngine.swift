import Foundation

protocol AnalyticsProviding {
    func track(event: AnalyticsEvent)
}

struct AnalyticsEvent {
    let name: String
    let metadata: [String: String]

    init(name: String, metadata: [String: String] = [:]) {
        self.name = name
        self.metadata = metadata
    }
}

final class AnalyticsEngine: AnalyticsProviding {
    static let shared = AnalyticsEngine()

    private init() {}

    func track(event: AnalyticsEvent) {
        #if DEBUG
        print("Analytics event: \(event.name) -> \(event.metadata)")
        #endif
    }
}
