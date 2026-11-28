import SwiftUI
import WatchKit

/// Press and hold for 3 seconds to exit — the friction stand-in for Apple's
/// "turn the Digital Crown to unlock". An amber ring fills while held; letting
/// go early drains it again. Haptic ticks each second.
struct HoldToExitButton: View {
    var duration: TimeInterval = 3
    let onComplete: (TimeInterval) -> Void

    @State private var progress: CGFloat = 0
    @State private var pressStartedAt: Date?
    @State private var completed = false
    @State private var tickTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(SchoolTheme.amber.opacity(0.25), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(SchoolTheme.amber, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: progress > 0 ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(SchoolTheme.amber)
            }
            .frame(width: 26, height: 26)

            Text(pressStartedAt == nil ? "Hold to Exit" : "Keep holding…")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.white.opacity(pressStartedAt == nil ? 0.08 : 0.16)))
        .contentShape(Capsule())
        .onLongPressGesture(minimumDuration: duration, maximumDistance: 40) {
            finish()
        } onPressingChanged: { pressing in
            pressing ? begin() : cancel()
        }
        .accessibilityLabel("Exit School Mode")
        .accessibilityHint("Press and hold for \(Int(duration)) seconds")
        .accessibilityAddTraits(.isButton)
    }

    private func begin() {
        completed = false
        pressStartedAt = .now
        WKInterfaceDevice.current().play(.start)
        withAnimation(.linear(duration: duration)) { progress = 1 }

        tickTask?.cancel()
        tickTask = Task { @MainActor in
            for _ in 1..<Int(duration) {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                WKInterfaceDevice.current().play(.click)
            }
        }
    }

    private func cancel() {
        tickTask?.cancel()
        guard !completed else { return }
        pressStartedAt = nil
        withAnimation(.easeOut(duration: 0.25)) { progress = 0 }
    }

    private func finish() {
        tickTask?.cancel()
        completed = true
        let held = pressStartedAt.map { Date.now.timeIntervalSince($0) } ?? duration
        pressStartedAt = nil
        WKInterfaceDevice.current().play(.success)
        onComplete(held)
        progress = 0
    }
}

#Preview {
    HoldToExitButton { _ in }
        .padding()
        .background(.black)
}
