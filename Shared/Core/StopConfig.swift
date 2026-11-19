import Foundation

/// Which stop to watch, how long it takes to walk there, and which routes to show.
struct StopConfig: Hashable, Sendable {
    /// GTFS stop_id, e.g. "30" (the website shows it zero-padded as "000030").
    var stopID: String
    /// Minutes it takes to get from your desk to the stop.
    var walkMinutes: Int
    /// Route numbers to show, e.g. ["195", "199"]. Empty means every route.
    var routes: Set<String>

    static let `default` = StopConfig(stopID: "30", walkMinutes: 5, routes: [])

    init(stopID: String, walkMinutes: Int, routes: Set<String>) {
        self.stopID = stopID
        self.walkMinutes = max(0, walkMinutes)
        self.routes = routes
    }

    /// Builds a config from loosely typed user input (settings screen or widget options).
    init(rawStopID: String, walkMinutes: Int, rawRoutes: String) {
        self.init(
            stopID: Self.normalize(stopID: rawStopID),
            walkMinutes: walkMinutes,
            routes: Self.parseRoutes(rawRoutes)
        )
    }

    /// Accepts "30", "000030" or a pasted Translink stop URL and returns the GTFS stop_id ("30").
    static func normalize(stopID raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = text.range(of: "stops/") {
            text = String(text[range.upperBound...].prefix(while: { $0 != "/" && $0 != "?" && $0 != "#" }))
        }
        guard !text.isEmpty else { return Self.default.stopID }
        let withoutPadding = text.drop(while: { $0 == "0" })
        return withoutPadding.isEmpty ? "0" : String(withoutPadding)
    }

    /// "195, 199" -> ["195", "199"]
    static func parseRoutes(_ raw: String) -> Set<String> {
        let parts = raw
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == ";" })
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
        return Set(parts)
    }

    var stopName: String { KnownStops.name(for: stopID) }
    var walkInterval: TimeInterval { TimeInterval(walkMinutes * 60) }
}

/// Short names for stops we know about. Anything else uses the full name from
/// the bundled stop list, or "Stop <id>".
enum KnownStops {
    private static let names: [String: String] = [
        "30": "Adelaide St, Stop 30",
        "724": "Alford St, Stop 12",
        "725": "Alford St, Stop 12",
    ]

    /// Destinations by stop, then route. The live feed doesn't include
    /// headsigns, so these come from the Translink stop page.
    private static let headsigns: [String: [String: String]] = [
        "30": [
            "195": "Merthyr",
            "196": "New Farm",
            "199": "Teneriffe",
        ],
        // City-bound side of Merthyr Rd at Alford St.
        "725": [
            "199": "City & West End",
            "N199": "City & West End",
        ],
        "724": [
            "199": "Teneriffe",
            "N199": "Teneriffe",
        ],
    ]

    static func name(for stopID: String) -> String {
        names[stopID] ?? StopDirectory.stop(id: stopID)?.name ?? "Stop \(stopID)"
    }

    static func headsign(stopID: String, route: String) -> String? {
        headsigns[stopID]?[route]
    }
}
