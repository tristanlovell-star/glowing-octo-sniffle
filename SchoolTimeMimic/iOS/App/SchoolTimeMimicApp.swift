import SwiftUI

@main
struct SchoolTimeMimicApp: App {
    @StateObject private var watch: PhoneSessionManager
    @StateObject private var screenTime: ScreenTimeManager
    @StateObject private var history: UnlockHistoryStore
    @StateObject private var auth = ParentAuthManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let watch = PhoneSessionManager()
        let history = UnlockHistoryStore()
        let screenTime = ScreenTimeManager(watch: watch)
        watch.onUnlockEvent = { history.add($0) }
        watch.activate()

        _watch = StateObject(wrappedValue: watch)
        _history = StateObject(wrappedValue: history)
        _screenTime = StateObject(wrappedValue: screenTime)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(watch)
                .environmentObject(screenTime)
                .environmentObject(history)
                .environmentObject(auth)
                .tint(SchoolTheme.amber)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: screenTime.refresh()
            case .background: auth.lock()      // never leave the dashboard open
            default: break
            }
        }
    }
}
