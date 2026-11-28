import SwiftUI

/// What the child sees when they open the iPhone app: the current state and
/// a small lock button for a parent.
struct ChildHomeView: View {
    @EnvironmentObject private var screenTime: ScreenTimeManager
    @EnvironmentObject private var watch: PhoneSessionManager
    let openParentArea: () -> Void

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { timeline in
                let context = screenTime.context
                let active = context.isSchoolModeActive(at: timeline.date)

                VStack(spacing: 28) {
                    Label(active ? "School Mode Active" : "School Mode Off",
                          systemImage: active ? "graduationcap.fill" : "moon.zzz.fill")
                        .font(.subheadline.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(active ? SchoolTheme.amber : Color.secondary)

                    SchooltimeClockFace(
                        date: timeline.date,
                        detail: context.statusDetail(at: timeline.date),
                        dayProgress: context.override == .followSchedule ? context.schedule.dayProgress(at: timeline.date) : nil,
                        isActive: active
                    )
                    .frame(maxWidth: 300)

                    Text(active
                         ? "Distracting apps are blocked until school finishes."
                         : "Apps are available. School Mode turns on automatically during school hours.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    Spacer()

                    watchStatus
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: openParentArea) {
                        Label("Parent", systemImage: "lock.fill")
                    }
                }
            }
        }
    }

    private var watchStatus: some View {
        HStack(spacing: 8) {
            Image(systemName: watch.isPaired ? "applewatch" : "applewatch.slash")
            Text(watch.isPaired
                 ? (watch.isWatchAppInstalled ? "Apple Watch connected" : "Install SchoolTime on Apple Watch")
                 : "No Apple Watch paired")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}
