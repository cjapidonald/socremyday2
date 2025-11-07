import CoreData
import Foundation

struct DailyScore: Equatable {
    let dayStart: Date
    let totalPoints: Double
}

final class ScoresRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func dailyScores(in range: ClosedRange<Date>, cutoffHour: Int, cutoffMinute: Int = 0) throws -> [DailyScore] {
        try context.performAndReturn {
            let lower = appDayRange(for: range.lowerBound, cutoffHour: cutoffHour, cutoffMinute: cutoffMinute).start
            let upper = appDayRange(for: range.upperBound, cutoffHour: cutoffHour, cutoffMinute: cutoffMinute).end

            let request = DeedEntryMO.fetchRequest()
            request.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp < %@", lower as NSDate, upper as NSDate)
            let entries = try context.fetch(request)

            var totals: [Date: Double] = [:]
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone.current

            for entry in entries {
                let bucketStart = appDayRange(for: entry.timestamp, cutoffHour: cutoffHour, cutoffMinute: cutoffMinute, calendar: calendar).start
                totals[bucketStart, default: 0] += entry.computedPoints
            }

            return totals
                .map { DailyScore(dayStart: $0.key, totalPoints: $0.value) }
                .sorted { $0.dayStart < $1.dayStart }
        }
    }
}
