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
    private var settings = StoredStopSettings()
    @StateObject private var model = DeparturesModel()
    @State private var showingSettings = false

    var body: some View {
        let config = settings.config
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 15)) { context in
                let upcoming = model.departures.upcoming(at: context.date)
                List {
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
            .navigationTitle("Stop \(config.stopID)")
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
                StopSettingsForm(stopID: settings.$stopID, walkMinutes: settings.$walkMinutes, routes: settings.$routes)
            }
            .task(id: config) {
                await model.keepRefreshing(config: config)
            }
        }
    }
}

#Preview {
    WatchContentView()
}
