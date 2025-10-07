import Foundation

/// Returns the start and end boundaries for an "app day" using the provided cutoff hour.
/// The returned range is half-open: start <= date < end.
func appDayRange(
    for date: Date,
    cutoffHour: Int,
    calendar inputCalendar: Calendar = Calendar(identifier: .gregorian)
) -> (start: Date, end: Date) {
    var calendar = inputCalendar
    calendar.timeZone = inputCalendar.timeZone
    calendar.locale = inputCalendar.locale

    let adjusted = calendar.date(byAdding: .hour, value: -cutoffHour, to: date) ?? date
    let dayStart = calendar.startOfDay(for: adjusted)
    let rangeStart = calendar.date(byAdding: .hour, value: cutoffHour, to: dayStart) ?? dayStart
    let rangeEnd = calendar.date(byAdding: .day, value: 1, to: rangeStart) ?? rangeStart
    return (start: rangeStart, end: rangeEnd)
}
