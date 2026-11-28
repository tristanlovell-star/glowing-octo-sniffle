import SwiftUI
import WatchConnectivity

@main
struct SchoolTimeWatchApp: App {
    // Singletons so WatchConnectivity is ready even when watchOS launches the
    // app in the background just to deliver new settings from the iPhone.
    @StateObject private var controller = WatchSchoolModeController.shared
    @StateObject private var runtime = ExtendedRuntimeManager()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(controller)
                .environmentObject(runtime)
        }
        .backgroundTask(.watchConnectivity) {
            await WatchSchoolModeController.shared.waitForPendingContent()
        }
    }
}
