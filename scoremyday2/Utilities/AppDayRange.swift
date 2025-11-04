import Foundation

/// Returns the start and end boundaries for an "app day" using the provided cutoff hour and minute.
/// The returned range is half-open: start <= date < end.
func appDayRange(
    for date: Date,
    cutoffHour: Int,
    cutoffMinute: Int = 0,
    calendar inputCalendar: Calendar = Calendar(identifier: .gregorian)
) -> (start: Date, end: Date) {
    var calendar = inputCalendar
    calendar.timeZone = inputCalendar.timeZone
    calendar.locale = inputCalendar.locale

    // Adjust by subtracting the cutoff time to find which "app day" this date belongs to
    var adjusted = calendar.date(byAdding: .hour, value: -cutoffHour, to: date) ?? date
    adjusted = calendar.date(byAdding: .minute, value: -cutoffMinute, to: adjusted) ?? adjusted

    // Get the start of the calendar day for the adjusted date
    let dayStart = calendar.startOfDay(for: adjusted)

    // Add back the cutoff hour and minute to get the range start
    var rangeStart = calendar.date(byAdding: .hour, value: cutoffHour, to: dayStart) ?? dayStart
    rangeStart = calendar.date(byAdding: .minute, value: cutoffMinute, to: rangeStart) ?? rangeStart

    // The range end is exactly 24 hours after the start
    let rangeEnd = calendar.date(byAdding: .day, value: 1, to: rangeStart) ?? rangeStart
    return (start: rangeStart, end: rangeEnd)
}
