import SwiftUI

@main
struct BusTimesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    private var settings = StoredCommuteSettings()
    @StateObject private var model = DeparturesModel()
    @StateObject private var appLocation = AppLocation()
    @State private var showingSettings = false

    var body: some View {
        let stop = settings.commute.resolve(location: appLocation.location)
        let config = stop.config
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 15)) { context in
                List {
                    Section {
                        Picker("Show", selection: settings.$selection) {
                            Text("Nearest").tag(StopSelection.nearest.rawValue)
                            Text("Home").tag(StopSelection.home.rawValue)
                            Text("Work").tag(StopSelection.work.rawValue)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())

                        StopHeader(stop: stop, locationAuthorized: appLocation.isAuthorized)
                    }

                    if let next = model.departures.upcoming(at: context.date).nextCatchable(at: context.date, walkMinutes: config.walkMinutes) {
                        Section {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(TimeFormatting.leaveText(for: next, walkMinutes: config.walkMinutes, now: context.date))
                                    .font(.largeTitle.weight(.bold))
                                Text("to catch the \(next.route) at \(TimeFormatting.clock(next.time)) (\(config.walkMinutes) min walk)")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Section("Next buses") {
                        let upcoming = model.departures.upcoming(at: context.date)
                        if upcoming.isEmpty {
                            Text(model.isLoading ? "Loading…" : "No buses in the next hour.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(upcoming) { departure in
                            DepartureRow(departure: departure, walkMinutes: config.walkMinutes, now: context.date)
                        }
                    }

                    if let error = model.errorMessage {
                        Section {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                    }

                    if appLocation.status == .denied || appLocation.status == .restricted {
                        Section {
                            Label("Location is off for Bus Times, so “Nearest” goes by time of day. Turn it on in Settings › Bus Times › Location (choose “While Using the App or Widgets”).", systemImage: "location.slash")
                                .font(.footnote)
                        }
                    }

                    Section {
                        if let fetchedAt = model.fetchedAt {
                            Text("Updated \(fetchedAt.formatted(date: .omitted, time: .standard)). Live data from Translink.")
                        }
                        Text("Widgets have their own settings: touch and hold a widget and tap Edit Widget. “Nearest” widgets switch between your home and work stops automatically.")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Bus Times")
            .refreshable {
                appLocation.start()
                await model.refresh(config: config)
            }
            .toolbar {
                Button {
                    showingSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    CommuteSettingsForm(
                        homeStopID: settings.$homeStopID,
                        homeWalkMinutes: settings.$homeWalkMinutes,
                        homeRoutes: settings.$homeRoutes,
                        workStopID: settings.$workStopID,
                        workWalkMinutes: settings.$workWalkMinutes,
                        workRoutes: settings.$workRoutes
                    )
                    .navigationTitle("Your Stops")
                    .toolbar {
                        Button("Done") { showingSettings = false }
                    }
                }
            }
            .onAppear { appLocation.start() }
            .task(id: config) {
                await model.keepRefreshing(config: config)
            }
        }
    }
}

#Preview {
    ContentView()
}
