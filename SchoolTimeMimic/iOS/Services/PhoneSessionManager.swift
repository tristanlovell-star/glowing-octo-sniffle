import Foundation
import WatchConnectivity

/// iPhone side of WatchConnectivity.
/// - Pushes `SchoolModeContext` with `updateApplicationContext` (latest-state-wins).
/// - Receives `UnlockEvent`s queued by the watch with `transferUserInfo`.
/// - Answers the watch's "send me the context" message when it launches.
final class PhoneSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var isPaired = false
    @Published private(set) var isWatchAppInstalled = false
    @Published private(set) var isReachable = false
    @Published private(set) var lastSyncError: String?
    @Published private(set) var lastPushedAt: Date?

    /// Called on the main actor for every unlock event that arrives.
    var onUnlockEvent: (@MainActor (UnlockEvent) -> Void)?
    /// Supplies the context when the watch asks for it.
    var contextProvider: (() -> SchoolModeContext)?

    private var pendingContext: SchoolModeContext?
    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    func push(_ context: SchoolModeContext) {
        guard let session else { return }
        guard session.activationState == .activated else {
            pendingContext = context
            return
        }
        guard session.isPaired, session.isWatchAppInstalled else { return }
        do {
            try session.updateApplicationContext(context.applicationContext())
            DispatchQueue.main.async {
                self.lastSyncError = nil
                self.lastPushedAt = .now
            }
        } catch {
            DispatchQueue.main.async { self.lastSyncError = error.localizedDescription }
        }
    }

    private func publishState(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable
        }
    }

    private func deliver(_ userInfo: [String: Any]) {
        guard let event = UnlockEvent(userInfo: userInfo) else { return }
        Task { @MainActor in self.onUnlockEvent?(event) }
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        publishState(session)
        // Unlock events queued while this app wasn't running are delivered
        // through didReceiveUserInfo right after activation.
        guard state == .activated else { return }
        if let pending = pendingContext ?? contextProvider?() {
            pendingContext = nil
            push(pending)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // The user switched to a different watch; start talking to the new one.
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        publishState(session)
        if session.isWatchAppInstalled, let context = contextProvider?() {
            push(context)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        publishState(session)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        deliver(userInfo)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        if message[SchoolModeContext.requestMessageKey] != nil,
           let context = contextProvider?(),
           let reply = try? context.applicationContext() {
            replyHandler(reply)
        } else if UnlockEvent(userInfo: message) != nil {
            deliver(message)
            replyHandler(["ok": true])
        } else {
            replyHandler([:])
        }
    }
}
