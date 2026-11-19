import CoreLocation
import Foundation

/// Which of your two stops a widget (or the app) should show.
enum StopSelection: String, CaseIterable, Codable, Sendable {
    /// Whichever stop is closer to you right now (falls back to time of day).
    case nearest
    case home
    case work
}

enum Place: String, Sendable {
    case home
    case work

    var title: String { self == .home ? "Home" : "Work" }
    var symbol: String { self == .home ? "house.fill" : "briefcase.fill" }
}

/// The stop that was picked, and why.
struct ResolvedStop: Hashable, Sendable {
    enum Reason: Hashable, Sendable {
        /// You picked this stop explicitly.
        case chosen
        /// It's the closer of your two stops.
        case nearest
        /// Location wasn't available, so it went by the time of day.
        case timeOfDay
    }

    let place: Place
    let config: StopConfig
    let reason: Reason

    var reasonText: String? {
        switch reason {
        case .chosen: return nil
        case .nearest: return "Nearest stop to you"
        case .timeOfDay: return "Location unavailable, so going by time of day"
        }
    }
}

/// Your home stop (for the trip into work) and work stop (for the trip home).
struct CommuteConfig: Hashable, Sendable {
    var selection: StopSelection
    var home: StopConfig
    var work: StopConfig

    static let `default` = CommuteConfig(
        selection: .nearest,
        // Merthyr Rd at Alford Street, stop 12 — the city-bound side (route 199 to the City).
        home: StopConfig(stopID: "725", walkMinutes: 3, routes: []),
        // Adelaide Street Stop 30 near Macrossan St.
        work: StopConfig(stopID: "30", walkMinutes: 5, routes: [])
    )

    /// Picks the stop to show. With `.nearest`, compares your distance to the
    /// two stops; without a location, uses the home stop before midday and the
    /// work stop after.
    func resolve(location: CLLocation?, now: Date = Date(), calendar: Calendar = .current) -> ResolvedStop {
        switch selection {
        case .home:
            return ResolvedStop(place: .home, config: home, reason: .chosen)
        case .work:
            return ResolvedStop(place: .work, config: work, reason: .chosen)
        case .nearest:
            if let location,
               let homeStop = StopDirectory.stop(id: home.stopID),
               let workStop = StopDirectory.stop(id: work.stopID) {
                let toHome = location.distance(from: homeStop.location)
                let toWork = location.distance(from: workStop.location)
                return toHome <= toWork
                    ? ResolvedStop(place: .home, config: home, reason: .nearest)
                    : ResolvedStop(place: .work, config: work, reason: .nearest)
            }
            let hour = calendar.component(.hour, from: now)
            return hour < 12
                ? ResolvedStop(place: .home, config: home, reason: .timeOfDay)
                : ResolvedStop(place: .work, config: work, reason: .timeOfDay)
        }
    }
}
