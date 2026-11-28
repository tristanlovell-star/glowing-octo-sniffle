import SwiftUI

struct RootView: View {
    @EnvironmentObject private var screenTime: ScreenTimeManager
    @EnvironmentObject private var auth: ParentAuthManager
    @State private var showParentArea = false

    var body: some View {
        Group {
            if screenTime.isAuthorized {
                ChildHomeView(openParentArea: { showParentArea = true })
            } else {
                AuthorizationView()
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showParentArea, onDismiss: { auth.lock() }) {
            ParentArea(close: {
                auth.lock()
                showParentArea = false
            })
        }
    }
}

/// PIN / Face ID gate first, then the dashboard.
private struct ParentArea: View {
    @EnvironmentObject private var auth: ParentAuthManager
    let close: () -> Void

    var body: some View {
        if auth.isUnlocked {
            DashboardView(close: close)
        } else {
            ParentGateView(onCancel: close)
        }
    }
}
