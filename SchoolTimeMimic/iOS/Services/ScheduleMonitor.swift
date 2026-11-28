import DeviceActivity
import Foundation

extension DeviceActivityName {
    /// One repeating activity per school weekday, e.g. "school.weekday.2" for Monday.
    static func schoolDay(_ weekday: Int) -> Self { Self("school.weekday.\(weekday)") }
}

/// Registers the weekly schedule with DeviceActivity so the monitor extension
/// is woken at the start and end of each school day.
enum ScheduleMonitor {
    private static let center = DeviceActivityCenter()

    enum ScheduleError: LocalizedError {
        case tooShort
        var errorDescription: String? {
            "School hours must be at least \(SchoolSchedule.minimumIntervalMinutes) minutes long."
        }
    }

    static func apply(_ schedule: SchoolSchedule) throws {
        center.stopMonitoring()
        guard schedule.isEnabled, !schedule.weekdays.isEmpty else { return }
        guard schedule.isValid else { throw ScheduleError.tooShort }

        for weekday in schedule.weekdays.sorted() {
            let activitySchedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: schedule.startHour, minute: schedule.startMinute, weekday: weekday),
                intervalEnd: DateComponents(hour: schedule.endHour, minute: schedule.endMinute, weekday: weekday),
                repeats: true
            )
            try center.startMonitoring(.schoolDay(weekday), during: activitySchedule)
        }
    }

    static var monitoredActivities: [DeviceActivityName] { center.activities }
}
