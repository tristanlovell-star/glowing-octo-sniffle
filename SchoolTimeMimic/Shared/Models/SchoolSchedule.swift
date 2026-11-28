import Foundation

/// A weekly school-hours schedule, e.g. Monday–Friday, 8:30 AM – 3:00 PM.
///
/// Intervals are same-day only (start must be before end), which is all a
/// school day ever needs and keeps the maths — and DeviceActivity — simple.
struct SchoolSchedule: Codable, Equatable, Hashable {
    /// `Calendar` weekday numbers: 1 = Sunday, 2 = Monday … 7 = Saturday.
    var weekdays: Set<Int>
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var isEnabled: Bool

    static let `default` = SchoolSchedule(
        weekdays: [2, 3, 4, 5, 6],
        startHour: 8, startMinute: 30,
        endHour: 15, endMinute: 0,
        isEnabled: true
    )

    /// DeviceActivity refuses intervals shorter than 15 minutes.
    static let minimumIntervalMinutes = 15

    var startMinuteOfDay: Int { startHour * 60 + startMinute }
    var endMinuteOfDay: Int { endHour * 60 + endMinute }

    var isValid: Bool {
        !weekdays.isEmpty && endMinuteOfDay - startMinuteOfDay >= Self.minimumIntervalMinutes
    }

    // MARK: - Evaluating the schedule

    func isActive(at date: Date = .now, calendar: Calendar = .current) -> Bool {
        guard isEnabled, isValid else { return false }
        guard weekdays.contains(calendar.component(.weekday, from: date)) else { return false }
        let minute = Self.minuteOfDay(date, calendar: calendar)
        return minute >= startMinuteOfDay && minute < endMinuteOfDay
    }

    /// A stable identifier for the school-day interval containing `date`
    /// (e.g. `"2026-11-30"`), or `nil` when outside school hours.
    func intervalID(at date: Date = .now, calendar: Calendar = .current) -> String? {
        guard isActive(at: date, calendar: calendar) else { return nil }
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// End of the interval containing `date`, if any.
    func currentIntervalEnd(after date: Date = .now, calendar: Calendar = .current) -> Date? {
        guard isActive(at: date, calendar: calendar) else { return nil }
        return calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: date)
    }

    /// Start of the next school-day interval strictly after `date`.
    func nextStart(after date: Date = .now, calendar: Calendar = .current) -> Date? {
        guard isEnabled, isValid else { return nil }
        let today = calendar.startOfDay(for: date)
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  weekdays.contains(calendar.component(.weekday, from: day)),
                  let start = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: day)
            else { continue }
            if start > date { return start }
        }
        return nil
    }

    // MARK: - Display helpers

    var startTimeText: String { Self.timeText(hour: startHour, minute: startMinute) }
    var endTimeText: String { Self.timeText(hour: endHour, minute: endMinute) }
    var timeRangeText: String { "\(startTimeText) – \(endTimeText)" }

    /// "Mon–Fri", "Weekdays", "Mon, Wed, Fri", "No days".
    var weekdaySummary: String {
        let sorted = weekdays.sorted { Self.mondayFirstIndex($0) < Self.mondayFirstIndex($1) }
        if sorted.isEmpty { return "No days" }
        if Set(sorted) == [2, 3, 4, 5, 6] { return "Mon–Fri" }
        if sorted.count == 7 { return "Every day" }
        let symbols = Calendar.current.shortWeekdaySymbols
        return sorted.map { symbols[$0 - 1] }.joined(separator: ", ")
    }

    /// Weekdays in Monday-first order, for pickers.
    static let mondayFirstWeekdays = [2, 3, 4, 5, 6, 7, 1]

    private static func mondayFirstIndex(_ weekday: Int) -> Int {
        mondayFirstWeekdays.firstIndex(of: weekday) ?? 0
    }

    static func minuteOfDay(_ date: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func timeText(hour: Int, minute: Int) -> String {
        var c = DateComponents()
        c.hour = hour
        c.minute = minute
        let date = Calendar.current.date(from: c) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}
