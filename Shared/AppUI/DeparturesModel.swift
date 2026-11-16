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
struct StoredStopSettings: DynamicProperty {
    @AppStorage("stopID") var stopID = "000030"
    @AppStorage("walkMinutes") var walkMinutes = 5
    @AppStorage("routes") var routes = ""

    var config: StopConfig {
        StopConfig(rawStopID: stopID, walkMinutes: walkMinutes, rawRoutes: routes)
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

struct StopSettingsForm: View {
    @Binding var stopID: String
    @Binding var walkMinutes: Int
    @Binding var routes: String

    var body: some View {
        Form {
            Section {
                TextField("Stop ID", text: $stopID)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            } header: {
                Text("Stop")
            } footer: {
                Text("The number at the end of the Translink stop page, e.g. 000030 for Adelaide St Stop 30.")
            }

            Section {
                Stepper("\(walkMinutes) min", value: $walkMinutes, in: 0...60)
            } header: {
                Text("Walk to stop")
            } footer: {
                Text("Used to work out when you need to leave.")
            }

            Section {
                TextField("All routes", text: $routes)
            } header: {
                Text("Routes")
            } footer: {
                Text("Optional. Comma-separated, e.g. 195, 199.")
            }
        }
    }
}
