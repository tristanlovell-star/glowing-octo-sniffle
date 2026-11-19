import SwiftUI

@main
struct BusTimesWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
    }
}

struct WatchContentView: View {
    private var settings = StoredCommuteSettings()
    @StateObject private var model = DeparturesModel()
    @StateObject private var appLocation = AppLocation()
    @State private var showingSettings = false

    var body: some View {
        let stop = settings.commute.resolve(location: appLocation.location)
        let config = stop.config
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 15)) { context in
                let upcoming = model.departures.upcoming(at: context.date)
                List {
                    Picker("Show", selection: settings.$selection) {
                        Text("Nearest").tag(StopSelection.nearest.rawValue)
                        Text("Home").tag(StopSelection.home.rawValue)
                        Text("Work").tag(StopSelection.work.rawValue)
                    }

                    StopHeader(stop: stop, locationAuthorized: appLocation.isAuthorized)
                        .listRowBackground(Color.clear)

                    if let next = upcoming.nextCatchable(at: context.date, walkMinutes: config.walkMinutes) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(TimeFormatting.leaveText(for: next, walkMinutes: config.walkMinutes, now: context.date))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.tint)
                            Text("\(next.route) at \(TimeFormatting.clock(next.time))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.clear)
                    }

                    if upcoming.isEmpty {
                        Text(model.isLoading ? "Loading…" : (model.errorMessage ?? "No buses in the next hour."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(upcoming) { departure in
                        DepartureRow(departure: departure, walkMinutes: config.walkMinutes, now: context.date)
                    }

                    if let fetchedAt = model.fetchedAt {
                        Text("Updated \(TimeFormatting.clock(fetchedAt))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle(stop.place.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                CommuteSettingsForm(
                    homeStopID: settings.$homeStopID,
                    homeWalkMinutes: settings.$homeWalkMinutes,
                    homeRoutes: settings.$homeRoutes,
                    workStopID: settings.$workStopID,
                    workWalkMinutes: settings.$workWalkMinutes,
                    workRoutes: settings.$workRoutes
                )
            }
            .onAppear { appLocation.start() }
            .task(id: config) {
                await model.keepRefreshing(config: config)
            }
        }
    }
}

#Preview {
    WatchContentView()
}
