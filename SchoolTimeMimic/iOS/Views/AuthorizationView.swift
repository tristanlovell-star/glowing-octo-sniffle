import FamilyControls
import SwiftUI

/// First-run screen: asks a parent to approve Screen Time access.
struct AuthorizationView: View {
    @EnvironmentObject private var screenTime: ScreenTimeManager
    @State private var working = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                SchooltimeClockFace(date: .now, detail: "Set up SchoolTime", isActive: true)
                    .frame(width: 200)
                    .padding(.top, 40)

                VStack(spacing: 10) {
                    Text("SchoolTime needs a parent")
                        .font(.title2.bold())
                    Text("To block apps during school hours, a parent or guardian in this child's Family Sharing group approves with their own Apple ID. This also stops the child turning SchoolTime's Screen Time access off on their own.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        working = true
                        await screenTime.requestAuthorization()
                        working = false
                    }
                } label: {
                    Label("Ask a Parent to Approve", systemImage: "person.badge.shield.checkmark.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(.black)
                .disabled(working)

                if let error = screenTime.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                if screenTime.authorizationStatus == .denied {
                    Text("Access was declined. Approve it in Settings › Screen Time, or try again.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
        }
        .background(Color.black.ignoresSafeArea())
    }
}
