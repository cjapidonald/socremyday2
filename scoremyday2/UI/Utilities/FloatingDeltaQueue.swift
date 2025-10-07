import Foundation

struct FloatingDeltaQueue {
    private let spacing: TimeInterval
    private var nextAvailableStart: Date?

    init(spacing: TimeInterval = 0.08) {
        self.spacing = spacing
    }

    mutating func nextDelay(now: Date = Date()) -> TimeInterval {
        guard let nextAvailableStart else {
            self.nextAvailableStart = now.addingTimeInterval(spacing)
            return 0
        }

        let earliestStart = max(now, nextAvailableStart)
        let delay = max(0, earliestStart.timeIntervalSince(now))
        self.nextAvailableStart = earliestStart.addingTimeInterval(spacing)
        return delay
    }
}
