import SwiftUI

/// The full-screen Schooltime replica: black, amber ring, big time, date, a
/// "School Mode Active" indicator, and the hold-to-exit control.
struct SchooltimeFaceView: View {
    let date: Date
    @EnvironmentObject private var controller: WatchSchoolModeController
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        let context = controller.context

        VStack(spacing: 4) {
            ActiveIndicator(dimmed: isLuminanceReduced)

            SchooltimeClockFace(
                date: date,
                detail: context.statusDetail(at: date),
                dayProgress: context.override == .followSchedule ? context.schedule.dayProgress(at: date) : nil,
                isDimmed: isLuminanceReduced
            )
            .layoutPriority(1)

            if !isLuminanceReduced {
                HoldToExitButton { held in
                    controller.exitSchoolMode(holdDuration: held)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .persistentSystemOverlays(.hidden)
    }
}

/// "● SCHOOL MODE ACTIVE" with a slowly breathing dot.
private struct ActiveIndicator: View {
    let dimmed: Bool
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(SchoolTheme.amber)
                .frame(width: 5, height: 5)
                .opacity(dimmed ? 0.5 : (pulse ? 1 : 0.35))
            Text("School Mode Active")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .textCase(.uppercase)
                .foregroundStyle(SchoolTheme.amber.opacity(dimmed ? 0.5 : 0.9))
        }
        .onAppear {
            guard !dimmed else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SchooltimeFaceView(date: .now)
        .environmentObject(WatchSchoolModeController.shared)
}
