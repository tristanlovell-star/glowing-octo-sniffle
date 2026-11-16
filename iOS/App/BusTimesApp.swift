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
    private var settings = StoredStopSettings()
    @StateObject private var model = DeparturesModel()
    @State private var showingSettings = false

    var body: some View {
        let config = settings.config
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 15)) { context in
                List {
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

                    Section {
                        if let fetchedAt = model.fetchedAt {
                            Text("Updated \(fetchedAt.formatted(date: .omitted, time: .standard)). Live data from Translink.")
                        }
                        Text("To add the widget: touch and hold the Home Screen, tap Edit › Add Widget, and search for Bus Times. To change its stop or walk time, touch and hold the widget and tap Edit Widget.")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(config.stopName)
            .refreshable { await model.refresh(config: config) }
            .toolbar {
                Button {
                    showingSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    StopSettingsForm(stopID: settings.$stopID, walkMinutes: settings.$walkMinutes, routes: settings.$routes)
                        .navigationTitle("Settings")
                        .toolbar {
                            Button("Done") { showingSettings = false }
                        }
                }
            }
            .task(id: config) {
                await model.keepRefreshing(config: config)
            }
        }
    }
}

#Preview {
    ContentView()
}
