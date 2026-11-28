import Foundation
import WatchKit

/// Keeps the app frontmost and running while the Schooltime face is showing.
///
/// Uses a WKExtendedRuntimeSession of the type declared in Info.plist
/// (`WKBackgroundModes` = `mindfulness`, i.e. "Background Modes › Session type:
/// Mindfulness" in Xcode). watchOS caps a mindfulness session at about an hour,
/// so a new one is started each time the app becomes active again; between
/// sessions the per-app "Return to Clock" setting keeps the face up.
/// Sessions can only be started while the app is in the foreground.
final class ExtendedRuntimeManager: NSObject, ObservableObject, WKExtendedRuntimeSessionDelegate {
    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String?

    private var session: WKExtendedRuntimeSession?

    func start() {
        if let session, session.state == .running || session.state == .scheduled { return }
        let newSession = WKExtendedRuntimeSession()
        newSession.delegate = self
        newSession.start()
        session = newSession
    }

    func stop() {
        session?.invalidate()
        session = nil
    }

    // MARK: WKExtendedRuntimeSessionDelegate

    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        DispatchQueue.main.async {
            self.isRunning = true
            self.lastError = nil
        }
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        // Nothing to save — a fresh session starts on the next wrist raise.
    }

    func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isRunning = false
            if extendedRuntimeSession === self.session { self.session = nil }
            if let error { self.lastError = error.localizedDescription }
        }
    }
}
