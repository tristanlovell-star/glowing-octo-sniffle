import Foundation

/// How the parent has overridden the schedule from the dashboard.
enum ManualOverride: String, Codable, CaseIterable, Identifiable {
    /// Follow the weekly schedule.
    case followSchedule
    /// School Mode on right now, regardless of the schedule.
    case forceOn
    /// School Mode off (e.g. a holiday), regardless of the schedule.
    case forceOff

    var id: String { rawValue }

    var title: String {
        switch self {
        case .followSchedule: "Follow schedule"
        case .forceOn: "On now"
        case .forceOff: "Paused"
        }
    }
}

/// Everything the iPhone tells the watch (and its own extensions) about School Mode.
/// Sent to the watch with `WCSession.updateApplicationContext` and stored in the
/// App Group so the DeviceActivity extension can read it.
struct SchoolModeContext: Codable, Equatable {
    var schedule: SchoolSchedule
    var override: ManualOverride
    /// When the child exits the watch face during school hours, put it back the
    /// next time they lower their wrist — like Apple's Schooltime does.
    var relockOnWristDown: Bool
    var updatedAt: Date

    static let `default` = SchoolModeContext(
        schedule: .default,
        override: .followSchedule,
        relockOnWristDown: true,
        updatedAt: .distantPast
    )

    func isSchoolModeActive(at date: Date = .now) -> Bool {
        switch override {
        case .forceOn: true
        case .forceOff: false
        case .followSchedule: schedule.isActive(at: date)
        }
    }

    /// Whether `date` falls inside the parent's *scheduled* hours (ignores overrides).
    func isWithinScheduledHours(at date: Date = .now) -> Bool {
        schedule.isActive(at: date)
    }

    /// Identifies the current "lock period". An exit only lasts for the period it
    /// happened in, so the face comes back at the next school day — or as soon as
    /// the parent turns School Mode on again.
    func lockPeriodID(at date: Date = .now) -> String? {
        switch override {
        case .forceOff: nil
        case .forceOn: "manual-\(Int(updatedAt.timeIntervalSince1970))"
        case .followSchedule: schedule.intervalID(at: date)
        }
    }

    /// A short line such as "until 3:00 PM" or "Starts Mon 8:30 AM".
    func statusDetail(at date: Date = .now) -> String {
        switch override {
        case .forceOn:
            return "Turned on by parent"
        case .forceOff:
            return "Paused by parent"
        case .followSchedule:
            if let end = schedule.currentIntervalEnd(after: date) {
                return "until \(end.formatted(date: .omitted, time: .shortened))"
            }
            if let next = schedule.nextStart(after: date) {
                let day = Calendar.current.isDateInToday(next) ? "Today"
                    : Calendar.current.isDateInTomorrow(next) ? "Tomorrow"
                    : next.formatted(.dateTime.weekday(.abbreviated))
                return "Starts \(day) \(next.formatted(date: .omitted, time: .shortened))"
            }
            return "No school days scheduled"
        }
    }

    // MARK: - WatchConnectivity encoding

    static let contextKey = "schoolModeContext"
    /// Message key the watch sends (with `sendMessage`) to ask for the latest context.
    static let requestMessageKey = "requestContext"

    func applicationContext() throws -> [String: Any] {
        [Self.contextKey: try JSONEncoder().encode(self)]
    }

    init?(applicationContext: [String: Any]) {
        guard let data = applicationContext[Self.contextKey] as? Data,
              let decoded = try? JSONDecoder().decode(SchoolModeContext.self, from: data)
        else { return nil }
        self = decoded
    }

    init(schedule: SchoolSchedule, override: ManualOverride, relockOnWristDown: Bool, updatedAt: Date) {
        self.schedule = schedule
        self.override = override
        self.relockOnWristDown = relockOnWristDown
        self.updatedAt = updatedAt
    }
}
