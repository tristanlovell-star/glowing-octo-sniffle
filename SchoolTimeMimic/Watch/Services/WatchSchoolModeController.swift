import Foundation
import WatchConnectivity
import WatchKit

/// Watch-side state + WatchConnectivity.
/// - Receives `SchoolModeContext` from the iPhone (`updateApplicationContext`).
/// - Decides whether the Schooltime face should be showing.
/// - Logs manual exits and queues them to the iPhone with `transferUserInfo`,
///   which survives the iPhone app not running and the phone being out of range.
final class WatchSchoolModeController: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSchoolModeController()

    @Published private(set) var context: SchoolModeContext
    @Published private(set) var exitedPeriodID: String?
    @Published private(set) var recentExits: [UnlockEvent]
    @Published private(set) var pendingTransfers = 0
    @Published private(set) var lastContextReceivedAt: Date?

    private let defaults = UserDefaults.standard
    private enum Key {
        static let context = "watch.context.v1"
        static let exitedPeriod = "watch.exitedPeriod.v1"
        static let recentExits = "watch.recentExits.v1"
        static let unsent = "watch.unsentExits.v1"
    }

    /// Exits logged before WCSession finished activating.
    private var unsent: [UnlockEvent]

    private override init() {
        context = SharedStore.load(SchoolModeContext.self, key: Key.context) ?? .default
        exitedPeriodID = UserDefaults.standard.string(forKey: Key.exitedPeriod)
        recentExits = SharedStore.load([UnlockEvent].self, key: Key.recentExits) ?? []
        unsent = SharedStore.load([UnlockEvent].self, key: Key.unsent) ?? []
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - Face state

    func shouldShowFace(at date: Date = .now) -> Bool {
        guard context.isSchoolModeActive(at: date),
              let period = context.lockPeriodID(at: date) else { return false }
        return period != exitedPeriodID
    }

    /// School Mode is on, but the child has exited the face for this period.
    func isExited(at date: Date = .now) -> Bool {
        context.isSchoolModeActive(at: date) && !shouldShowFace(at: date)
    }

    /// Called when the 3-second hold completes.
    func exitSchoolMode(holdDuration: TimeInterval, at date: Date = .now) {
        let event = UnlockEvent(
            timestamp: date,
            duringScheduledHours: context.isWithinScheduledHours(at: date),
            schoolModeWasActive: context.isSchoolModeActive(at: date),
            holdDuration: holdDuration,
            deviceName: WKInterfaceDevice.current().name
        )
        exitedPeriodID = context.lockPeriodID(at: date)
        defaults.set(exitedPeriodID, forKey: Key.exitedPeriod)

        recentExits.insert(event, at: 0)
        if recentExits.count > 20 { recentExits.removeLast(recentExits.count - 20) }
        SharedStore.save(recentExits, key: Key.recentExits)

        send(event)
    }

    /// Puts the Schooltime face back.
    func relock() {
        exitedPeriodID = nil
        defaults.removeObject(forKey: Key.exitedPeriod)
    }

    func handleWristDown(at date: Date = .now) {
        if context.relockOnWristDown, isExited(at: date) { relock() }
    }

    // MARK: - Sending exits

    private func send(_ event: UnlockEvent) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              let info = try? event.userInfo()
        else {
            unsent.append(event)
            SharedStore.save(unsent, key: Key.unsent)
            return
        }
        WCSession.default.transferUserInfo(info)
        refreshPendingCount()
    }

    private func flushUnsent() {
        guard !unsent.isEmpty else { return }
        let queued = unsent
        unsent = []
        SharedStore.save(unsent, key: Key.unsent)
        queued.forEach(send)
    }

    private func refreshPendingCount() {
        let count = WCSession.default.outstandingUserInfoTransfers.count + unsent.count
        DispatchQueue.main.async { self.pendingTransfers = count }
    }

    // MARK: - Receiving context

    func requestLatestContext() {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated, session.isReachable else { return }
        session.sendMessage([SchoolModeContext.requestMessageKey: true], replyHandler: { [weak self] reply in
            if let context = SchoolModeContext(applicationContext: reply) { self?.apply(context) }
        }, errorHandler: nil)
    }

    private func apply(_ newContext: SchoolModeContext) {
        DispatchQueue.main.async {
            self.lastContextReceivedAt = .now
            guard newContext.updatedAt >= self.context.updatedAt else { return }
            self.context = newContext
            SharedStore.save(newContext, key: Key.context)
        }
    }

    /// Used by the `.watchConnectivity` background task: give pending data a
    /// moment to arrive before watchOS suspends the app again.
    func waitForPendingContent() async {
        for _ in 0..<20 {
            let session = WCSession.default
            if session.activationState == .activated && !session.hasContentPending { return }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        guard state == .activated else { return }
        if let context = SchoolModeContext(applicationContext: session.receivedApplicationContext) {
            apply(context)
        }
        flushUnsent()
        refreshPendingCount()
        requestLatestContext()
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let context = SchoolModeContext(applicationContext: applicationContext) { apply(context) }
    }

    func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        if error != nil {
            // Try again; transferUserInfo keeps queuing until the phone takes it.
            session.transferUserInfo(userInfoTransfer.userInfo)
        }
        refreshPendingCount()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable { requestLatestContext() }
    }
}
