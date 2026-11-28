import SwiftUI

/// Outside school hours: a dimmed ring, the time, and when Schooltime starts next.
struct IdleView: View {
    let date: Date
    @EnvironmentObject private var controller: WatchSchoolModeController

    var body: some View {
        VStack(spacing: 6) {
            Text("Schooltime Off")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            SchooltimeClockFace(
                date: date,
                detail: controller.context.statusDetail(at: date),
                isActive: false
            )

            if controller.context.updatedAt == .distantPast {
                Text("Open SchoolTime on iPhone to sync")
                    .font(.caption2)
                    .foregroundStyle(SchoolTheme.amber)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}
