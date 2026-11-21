import SwiftUI

@main
struct SpotterApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if store.data.onboarded {
                    RootView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(store)
            .tint(.orange)
            .task { await store.refreshHealth() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { store.saveNow() }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "figure.strengthtraining.traditional") }
                .tag(0)
            ProgramView()
                .tabItem { Label("Program", systemImage: "list.bullet.clipboard") }
                .tag(1)
            ProgressScreen()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(2)
            CoachView()
                .tabItem { Label("Coach", systemImage: "bubble.left.and.text.bubble.right") }
                .tag(3)
            EquipmentView()
                .tabItem { Label("Equipment", systemImage: "dumbbell") }
                .tag(4)
        }
        .fullScreenCover(isPresented: Binding(
            get: { store.data.activeSession != nil },
            set: { _ in })) {
            WorkoutView()
                .environmentObject(store)
                .tint(.orange)
        }
    }
}
