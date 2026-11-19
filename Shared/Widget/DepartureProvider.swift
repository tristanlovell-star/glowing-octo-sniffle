import CoreLocation
import WidgetKit

struct DepartureEntry: TimelineEntry {
    let date: Date
    /// The stop being shown (home or work) and why it was picked.
    let stop: ResolvedStop
    let departures: [Departure]
    let fetchedAt: Date?
    let errorMessage: String?

    var config: StopConfig { stop.config }
    /// e.g. "Work · Adelaide St, Stop 30"
    var stopTitle: String { "\(stop.place.title) · \(config.stopName)" }
    var upcoming: [Departure] { departures.upcoming(at: date) }
    var nextCatchable: Departure? { upcoming.nextCatchable(at: date, walkMinutes: config.walkMinutes) }

    func at(_ date: Date) -> DepartureEntry {
        DepartureEntry(date: date, stop: stop, departures: departures, fetchedAt: fetchedAt, errorMessage: errorMessage)
    }

    static var preview: DepartureEntry {
        let now = Date()
        let sample: [(String, Double, Int)] = [("199", 7, 60), ("199", 17, 0), ("195", 26, 180), ("199", 36, 0)]
        return DepartureEntry(
            date: now,
            stop: ResolvedStop(place: .work, config: CommuteConfig.default.work, reason: .nearest),
            departures: sample.enumerated().map { index, item in
                Departure(
                    tripID: "preview-\(index)",
                    route: item.0,
                    headsign: KnownStops.headsign(stopID: "30", route: item.0),
                    time: now.addingTimeInterval(item.1 * 60),
                    delaySeconds: item.2
                )
            },
            fetchedAt: now,
            errorMessage: nil
        )
    }
}

struct DepartureProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DepartureEntry {
        .preview
    }

    func snapshot(for configuration: BusStopIntent, in context: Context) async -> DepartureEntry {
        if context.isPreview { return .preview }
        return await loadEntry(for: configuration.commute)
    }

    func timeline(for configuration: BusStopIntent, in context: Context) async -> Timeline<DepartureEntry> {
        let entry = await loadEntry(for: configuration.commute)
        let now = entry.date

        // One fetch gives us exact bus times, so we can pre-build an entry for
        // every minute and the countdowns stay right between network refreshes.
        let minuteStart = Calendar.current.dateInterval(of: .minute, for: now)?.start ?? now
        var entries = [entry]
        for minute in 1...30 {
            entries.append(entry.at(minuteStart.addingTimeInterval(TimeInterval(minute * 60))))
        }

        // Ask for fresh data in a few minutes. iOS and watchOS decide when to
        // actually refresh (each widget gets a daily budget), so this is a
        // request, not a guarantee.
        // In "Nearest" mode each refresh also re-checks where you are.
        let refreshMinutes: Double
        if entry.errorMessage != nil {
            refreshMinutes = 5
        } else if entry.upcoming.isEmpty {
            refreshMinutes = 30
        } else {
            refreshMinutes = 10
        }
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(refreshMinutes * 60)))
    }

    #if os(watchOS)
    // Watch faces offer these ready-made choices when you add the complication.
    func recommendations() -> [AppIntentRecommendation<BusStopIntent>] {
        [
            AppIntentRecommendation(intent: BusStopIntent(selection: .nearest), description: "Nearest Stop"),
            AppIntentRecommendation(intent: BusStopIntent(selection: .home), description: "Home Stop"),
            AppIntentRecommendation(intent: BusStopIntent(selection: .work), description: "Work Stop"),
        ]
    }
    #endif

    private func loadEntry(for commute: CommuteConfig) async -> DepartureEntry {
        let now = Date()
        var location: CLLocation?
        if commute.selection == .nearest {
            location = await LocationFetcher.current()
        }
        let stop = commute.resolve(location: location, now: now)
        let config = stop.config
        do {
            let snapshot = try await DepartureService.fetch(config: config, now: now)
            return DepartureEntry(date: now, stop: stop, departures: snapshot.departures, fetchedAt: snapshot.fetchedAt, errorMessage: nil)
        } catch {
            let cached = DepartureService.cachedSnapshot(for: config)
            return DepartureEntry(
                date: now,
                stop: stop,
                departures: cached?.departures ?? [],
                fetchedAt: cached?.fetchedAt,
                errorMessage: "Can't reach Translink"
            )
        }
    }
}
