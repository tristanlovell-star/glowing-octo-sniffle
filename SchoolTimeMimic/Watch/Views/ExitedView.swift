import SwiftUI

/// Shown after the child exits the face while School Mode is on.
struct ExitedView: View {
    let date: Date
    @EnvironmentObject private var controller: WatchSchoolModeController

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "lock.open.fill")
                    .font(.title2)
                    .foregroundStyle(SchoolTheme.amber)

                Text(date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .monospacedDigit()

                Text("Schooltime paused")
                    .font(.headline)

                Text(controller.context.relockOnWristDown
                     ? "Comes back when you lower your wrist."
                     : "Comes back next school day.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    controller.relock()
                } label: {
                    Label("Resume Schooltime", systemImage: "graduationcap.fill")
                }
                .tint(SchoolTheme.amber)
                .padding(.top, 4)

                Label(controller.pendingTransfers > 0 ? "Exit will sync to iPhone" : "Exit sent to iPhone",
                      systemImage: controller.pendingTransfers > 0 ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color.black.ignoresSafeArea())
    }
}
