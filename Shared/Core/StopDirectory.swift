import CoreLocation
import Foundation

struct StopInfo: Sendable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double

    var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
}

/// Looks up any Translink stop's name and position from the bundled
/// `stops.csv` (built from Translink's timetable data by Tools/make_stops.py).
enum StopDirectory {
    private static let lock = NSLock()
    private static var cache: [String: StopInfo?] = [:]
    private static var fileText: String?

    static func stop(id: String) -> StopInfo? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[id] { return cached }
        let found = search(id: id)
        cache[id] = .some(found)
        return found
    }

    private static func search(id: String) -> StopInfo? {
        if fileText == nil {
            guard let url = Bundle.main.url(forResource: "stops", withExtension: "csv"),
                  let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            fileText = text
        }
        guard let text = fileText else { return nil }
        let prefix = id + ","
        for line in text.split(separator: "\n") where line.hasPrefix(prefix) {
            // stop_id,lat,lon,name (the name may itself contain commas)
            let parts = line.split(separator: ",", maxSplits: 3, omittingEmptySubsequences: false)
            guard parts.count == 4, let lat = Double(parts[1]), let lon = Double(parts[2]) else { return nil }
            return StopInfo(id: id, name: String(parts[3]), latitude: lat, longitude: lon)
        }
        return nil
    }
}
