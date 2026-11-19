import CoreLocation
import Foundation

/// Gets a rough current location (to within a few hundred metres, which is
/// plenty to tell home from work) for widgets and complications.
///
/// It never asks for permission itself — the app does that — and gives up
/// quickly so a widget refresh is never held up waiting on GPS.
@MainActor
final class LocationFetcher: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    /// A location fresher than `maxAge`, a new fix within `timeout`, or an older
    /// cached fix (up to 3 hours) as a last resort. `nil` if location is off.
    static func current(maxAge: TimeInterval = 10 * 60, timeout: TimeInterval = 6) async -> CLLocation? {
        let fetcher = LocationFetcher()
        return await fetcher.fetch(maxAge: maxAge, timeout: timeout)
    }

    private func fetch(maxAge: TimeInterval, timeout: TimeInterval) async -> CLLocation? {
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return nil }

        if let cached = manager.location, -cached.timestamp.timeIntervalSinceNow < maxAge {
            return cached
        }

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        let fresh: CLLocation? = await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                self?.finish(nil)
            }
        }
        if let fresh { return fresh }
        if let cached = manager.location, -cached.timestamp.timeIntervalSinceNow < 3 * 60 * 60 {
            return cached
        }
        return nil
    }

    private func finish(_ location: CLLocation?) {
        continuation?.resume(returning: location)
        continuation = nil
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latest = locations.last
        Task { @MainActor in self.finish(latest) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(nil) }
    }
}
