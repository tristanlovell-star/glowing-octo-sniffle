import SwiftUI

/// Picks between the full-screen Schooltime face, the "paused" screen after a
/// manual exit, and the idle screen outside school hours. Re-evaluated every
/// minute by `TimelineView`, so the face appears and disappears on schedule.
struct WatchRootView: View {
    @EnvironmentObject private var controller: WatchSchoolModeController
    @EnvironmentObject private var runtime: ExtendedRuntimeManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            let showFace = controller.shouldShowFace(at: timeline.date)
            Group {
                if showFace {
                    SchooltimeFaceView(date: timeline.date)
                } else if controller.isExited(at: timeline.date) {
                    ExitedView(date: timeline.date)
                } else {
                    IdleView(date: timeline.date)
                }
            }
            .onChange(of: showFace, initial: true) { _, show in
                if show { runtime.start() } else { runtime.stop() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                controller.requestLatestContext()
                if controller.shouldShowFace(at: .now) { runtime.start() }
            case .inactive, .background:
                // Wrist lowered (or app left): like Apple's Schooltime, an exit
                // during school hours ends here and the face comes back.
                controller.handleWristDown()
            @unknown default:
                break
            }
        }
    }
}
