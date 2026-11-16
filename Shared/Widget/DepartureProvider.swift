import WidgetKit

struct DepartureEntry: TimelineEntry {
    let date: Date
    let config: StopConfig
    let departures: [Departure]
    let fetchedAt: Date?
    let errorMessage: String?

    var upcoming: [Departure] { departures.upcoming(at: date) }
    var nextCatchable: Departure? { upcoming.nextCatchable(at: date, walkMinutes: config.walkMinutes) }

    func at(_ date: Date) -> DepartureEntry {
        DepartureEntry(date: date, config: config, departures: departures, fetchedAt: fetchedAt, errorMessage: errorMessage)
    }

    static var preview: DepartureEntry {
        let now = Date()
        let sample: [(String, Double, Int)] = [("199", 7, 60), ("199", 17, 0), ("195", 26, 180), ("199", 36, 0)]
        return DepartureEntry(
            date: now,
            config: .default,
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
        return await loadEntry(for: configuration.config)
    }

    func timeline(for configuration: BusStopIntent, in context: Context) async -> Timeline<DepartureEntry> {
        let entry = await loadEntry(for: configuration.config)
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
    func recommendations() -> [AppIntentRecommendation<BusStopIntent>] {
        [AppIntentRecommendation(intent: BusStopIntent(), description: "Adelaide St, Stop 30")]
    }
    #endif

    private func loadEntry(for config: StopConfig) async -> DepartureEntry {
        let now = Date()
        do {
            let snapshot = try await DepartureService.fetch(config: config, now: now)
            return DepartureEntry(date: now, config: config, departures: snapshot.departures, fetchedAt: snapshot.fetchedAt, errorMessage: nil)
        } catch {
            let cached = DepartureService.cachedSnapshot(for: config)
            return DepartureEntry(
                date: now,
                config: config,
                departures: cached?.departures ?? [],
                fetchedAt: cached?.fetchedAt,
                errorMessage: "Can't reach Translink"
            )
        }
    }
}
