import Foundation

struct Departure: Codable, Hashable, Identifiable, Sendable {
    let tripID: String
    /// Route number as shown on the bus, e.g. "199".
    let route: String
    let headsign: String?
    /// Predicted time the bus leaves the stop (includes live delay).
    let time: Date
    let delaySeconds: Int?

    var id: String { tripID }

    /// The latest moment you can leave and still make this bus.
    func leaveTime(walkMinutes: Int) -> Date {
        time.addingTimeInterval(-TimeInterval(walkMinutes * 60))
    }

    var delayDescription: String? {
        guard let delaySeconds else { return nil }
        let minutes = Int((Double(delaySeconds) / 60).rounded())
        switch minutes {
        case ..<0: return "\(-minutes) min early"
        case 0: return "On time"
        default: return "\(minutes) min late"
        }
    }

    var isLate: Bool { (delaySeconds ?? 0) >= 120 }
}

/// A batch of departures fetched together.
struct DepartureSnapshot: Codable, Sendable {
    let stopID: String
    let departures: [Departure]
    let fetchedAt: Date
    /// When Translink generated the feed.
    let feedTimestamp: Date?
}

extension Array where Element == Departure {
    /// Departures still ahead at `date`. A bus that's "due" stays in the list for 30 seconds.
    func upcoming(at date: Date) -> [Departure] {
        filter { $0.time.timeIntervalSince(date) > -30 }
    }

    /// The first bus you can still catch if you leave at `date`.
    func nextCatchable(at date: Date, walkMinutes: Int) -> Departure? {
        first { $0.leaveTime(walkMinutes: walkMinutes).timeIntervalSince(date) > -30 }
    }
}

enum TimeFormatting {
    /// Whole minutes from `now` until `date`, never negative.
    static func minutes(until date: Date, from now: Date) -> Int {
        max(0, Int((date.timeIntervalSince(now) / 60).rounded(.down)))
    }

    /// "Now", "1 min", "12 min"
    static func countdown(to date: Date, from now: Date) -> String {
        let m = minutes(until: date, from: now)
        return m == 0 ? "Now" : "\(m) min"
    }

    /// "Leave now", "Leave in 4 min"
    static func leaveText(for departure: Departure, walkMinutes: Int, now: Date) -> String {
        let m = minutes(until: departure.leaveTime(walkMinutes: walkMinutes), from: now)
        return m == 0 ? "Leave now" : "Leave in \(m) min"
    }

    static func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
