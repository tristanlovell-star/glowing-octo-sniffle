import Foundation

enum DepartureError: LocalizedError {
    case badResponse(Int)

    var errorDescription: String? {
        switch self {
        case .badResponse(let code): return "Translink returned an error (\(code))."
        }
    }
}

/// Fetches live departures from Translink's public GTFS-Realtime feed.
///
/// The feed is open data: no API key, no account. The bus-only feed is about
/// 2 MB uncompressed (around 500 KB over the wire, since it's gzipped), and
/// covers every bus in South East Queensland, so we filter it down to one stop.
enum DepartureService {
    static let feedURL = URL(string: "https://gtfsrt.api.translink.com.au/api/realtime/SEQ/TripUpdates/Bus")!

    static func fetch(config: StopConfig, limit: Int = 8, now: Date = Date()) async throws -> DepartureSnapshot {
        var request = URLRequest(url: feedURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/x-protobuf", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw DepartureError.badResponse(http.statusCode)
        }

        let parsed = try GTFSRealtimeParser.arrivals(in: data, stopID: config.stopID)
        let departures = makeDepartures(from: parsed.arrivals, config: config, now: now, limit: limit)
        let snapshot = DepartureSnapshot(
            stopID: config.stopID,
            departures: departures,
            fetchedAt: now,
            feedTimestamp: parsed.feedTimestamp
        )
        save(snapshot)
        return snapshot
    }

    static func makeDepartures(from arrivals: [StopArrival], config: StopConfig, now: Date, limit: Int) -> [Departure] {
        var seenTrips = Set<String>()
        return arrivals
            .compactMap { arrival -> Departure? in
                // route_id looks like "199-4": route number, then a timetable version.
                let route = String(arrival.routeID.split(separator: "-").first ?? Substring(arrival.routeID))
                guard config.routes.isEmpty || config.routes.contains(route.uppercased()) else { return nil }
                guard arrival.time.timeIntervalSince(now) > -30 else { return nil }
                guard seenTrips.insert(arrival.tripID).inserted else { return nil }
                return Departure(
                    tripID: arrival.tripID,
                    route: route,
                    headsign: KnownStops.headsign(stopID: config.stopID, route: route),
                    time: arrival.time,
                    delaySeconds: arrival.delaySeconds
                )
            }
            .sorted { $0.time < $1.time }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Last known good result, for when the network is unavailable

    private static func cacheKey(for stopID: String) -> String { "departures.snapshot.\(stopID)" }

    static func save(_ snapshot: DepartureSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey(for: snapshot.stopID))
    }

    static func cachedSnapshot(for config: StopConfig) -> DepartureSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(for: config.stopID)),
              let snapshot = try? JSONDecoder().decode(DepartureSnapshot.self, from: data) else { return nil }
        // Re-apply the route filter in case it changed since the snapshot was saved.
        let filtered = snapshot.departures.filter {
            config.routes.isEmpty || config.routes.contains($0.route.uppercased())
        }
        return DepartureSnapshot(
            stopID: snapshot.stopID,
            departures: filtered,
            fetchedAt: snapshot.fetchedAt,
            feedTimestamp: snapshot.feedTimestamp
        )
    }
}
