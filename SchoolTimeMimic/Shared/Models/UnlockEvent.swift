import Foundation

/// One manual exit from the Schooltime face on the watch.
struct UnlockEvent: Codable, Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    /// True when the exit happened inside the parent's scheduled school hours.
    let duringScheduledHours: Bool
    /// True when School Mode was on at the time (scheduled or turned on manually).
    let schoolModeWasActive: Bool
    /// How long the button was held, in seconds.
    let holdDuration: TimeInterval
    /// The watch's name, e.g. "Sam's Apple Watch".
    let deviceName: String

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        duringScheduledHours: Bool,
        schoolModeWasActive: Bool,
        holdDuration: TimeInterval,
        deviceName: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.duringScheduledHours = duringScheduledHours
        self.schoolModeWasActive = schoolModeWasActive
        self.holdDuration = holdDuration
        self.deviceName = deviceName
    }

    // MARK: - WatchConnectivity encoding

    static let userInfoKey = "unlockEvent"

    func userInfo() throws -> [String: Any] {
        [Self.userInfoKey: try JSONEncoder().encode(self)]
    }

    init?(userInfo: [String: Any]) {
        guard let data = userInfo[Self.userInfoKey] as? Data,
              let decoded = try? JSONDecoder().decode(UnlockEvent.self, from: data)
        else { return nil }
        self = decoded
    }
}
