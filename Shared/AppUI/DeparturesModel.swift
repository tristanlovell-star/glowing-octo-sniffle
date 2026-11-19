import CoreLocation
import Foundation
import SwiftUI
import WidgetKit

/// Drives the in-app departure list on both iPhone and Apple Watch.
@MainActor
final class DeparturesModel: ObservableObject {
    @Published private(set) var departures: [Departure] = []
    @Published private(set) var fetchedAt: Date?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false

    func refresh(config: StopConfig) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let snapshot = try await DepartureService.fetch(config: config, limit: 12)
            departures = snapshot.departures
            fetchedAt = snapshot.fetchedAt
            errorMessage = nil
            // Reloads requested while the app is open don't use up the widget's refresh budget.
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            errorMessage = "Couldn't reach Translink. \(error.localizedDescription)"
            if departures.isEmpty, let cached = DepartureService.cachedSnapshot(for: config) {
                departures = cached.departures
                fetchedAt = cached.fetchedAt
            }
        }
    }

    /// Refreshes every 30 seconds until the surrounding task is cancelled.
    func keepRefreshing(config: StopConfig) async {
        while !Task.isCancelled {
            await refresh(config: config)
            try? await Task.sleep(for: .seconds(30))
        }
    }
}

/// Persisted app settings (separate from widget settings, which live on each widget).
struct StoredCommuteSettings: DynamicProperty {
    @AppStorage("selection") var selection = StopSelection.nearest.rawValue
    @AppStorage("homeStopID") var homeStopID = "725"
    @AppStorage("homeWalkMinutes") var homeWalkMinutes = 3
    @AppStorage("homeRoutes") var homeRoutes = ""
    @AppStorage("workStopID") var workStopID = "000030"
    @AppStorage("workWalkMinutes") var workWalkMinutes = 5
    @AppStorage("workRoutes") var workRoutes = ""

    var commute: CommuteConfig {
        CommuteConfig(
            selection: StopSelection(rawValue: selection) ?? .nearest,
            home: StopConfig(rawStopID: homeStopID, walkMinutes: homeWalkMinutes, rawRoutes: homeRoutes),
            work: StopConfig(rawStopID: workStopID, walkMinutes: workWalkMinutes, rawRoutes: workRoutes)
        )
    }
}

/// Asks for location permission (which the widgets and complications share)
/// and keeps a rough current location for the in-app "Nearest" view.
@MainActor
final class AppLocation: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var status: CLAuthorizationStatus
    private let manager: CLLocationManager

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.status = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isAuthorized: Bool { status == .authorizedWhenInUse || status == .authorizedAlways }

    /// Asks for permission the first time; afterwards just gets a fresh fix.
    func start() {
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if isAuthorized {
            manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        Task { @MainActor in
            self.status = newStatus
            if self.isAuthorized {
                self.manager.requestLocation()
                // Let "Nearest" widgets pick up the newly allowed location.
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latest = locations.last
        Task { @MainActor in self.location = latest }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

/// The "Home stop / Work stop" line at the top of the departure list.
struct StopHeader: View {
    let stop: ResolvedStop
    let locationAuthorized: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(stop.config.stopName, systemImage: stop.place.symbol)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var detail: String {
        let place = "\(stop.place.title) stop"
        switch stop.reason {
        case .chosen: return place
        case .nearest: return "\(place) · nearest to you"
        case .timeOfDay:
            return locationAuthorized
                ? "\(place) · finding your location…"
                : "\(place) · by time of day (location is off)"
        }
    }
}

struct DepartureRow: View {
    let departure: Departure
    let walkMinutes: Int
    let now: Date

    var body: some View {
        HStack(spacing: 10) {
            Text(departure.route)
                .font(.headline.monospacedDigit())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 1) {
                Text(TimeFormatting.clock(departure.time))
                    .font(.body.weight(.medium))
                if let headsign = departure.headsign {
                    Text(headsign)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let delay = departure.delayDescription {
                    Text(delay)
                        .font(.caption2)
                        .foregroundStyle(departure.isLate ? Color.orange : Color.secondary)
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 1) {
                Text(TimeFormatting.countdown(to: departure.time, from: now))
                    .font(.headline.monospacedDigit())
                if departure.leaveTime(walkMinutes: walkMinutes).timeIntervalSince(now) > -30 {
                    Text(TimeFormatting.leaveText(for: departure, walkMinutes: walkMinutes, now: now))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Too late to walk")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct CommuteSettingsForm: View {
    @Binding var homeStopID: String
    @Binding var homeWalkMinutes: Int
    @Binding var homeRoutes: String
    @Binding var workStopID: String
    @Binding var workWalkMinutes: Int
    @Binding var workRoutes: String

    var body: some View {
        Form {
            stopSection(title: "Home stop", symbol: "house.fill", stopID: $homeStopID, walk: $homeWalkMinutes, routes: $homeRoutes,
                        hint: "For the trip into work. 725 is Merthyr Rd at Alford St, stop 12 (city-bound side).")
            stopSection(title: "Work stop", symbol: "briefcase.fill", stopID: $workStopID, walk: $workWalkMinutes, routes: $workRoutes,
                        hint: "For the trip home. 000030 is Adelaide St Stop 30.")
            Section {
                Text("“Nearest” shows whichever of these stops is closer to you. If location is off, it shows the home stop before midday and the work stop after.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func stopSection(title: String, symbol: String, stopID: Binding<String>, walk: Binding<Int>, routes: Binding<String>, hint: String) -> some View {
        Section {
            TextField("Stop ID", text: stopID)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
            let id = StopConfig.normalize(stopID: stopID.wrappedValue)
            Text(StopDirectory.stop(id: id)?.name ?? "Unknown stop ID")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Stepper("Walk: \(walk.wrappedValue) min", value: walk, in: 0...60)
            TextField("All routes", text: routes)
        } header: {
            Label(title, systemImage: symbol)
        } footer: {
            Text(hint + " Routes are optional, e.g. 195, 199.")
        }
    }
}
