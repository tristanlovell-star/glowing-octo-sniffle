import SwiftUI

/// 4-digit PIN pad. Creates the PIN on first use (enter + confirm), verifies it
/// afterwards, and offers Face ID / Touch ID when the parent enabled it.
struct ParentGateView: View {
    @EnvironmentObject private var auth: ParentAuthManager

    /// Set to true to (re)create the PIN, e.g. from "Change PIN".
    var forceCreate = false
    var onFinished: (() -> Void)?
    var onCancel: () -> Void

    @State private var entry = ""
    @State private var firstEntry: String?
    @State private var message: String?
    @State private var shakes = 0

    private var isCreating: Bool { forceCreate || !auth.hasPIN }

    private var title: String {
        if isCreating { return firstEntry == nil ? "Create a Parent PIN" : "Confirm PIN" }
        return "Enter Parent PIN"
    }

    var body: some View {
        VStack(spacing: 28) {
            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
            }
            .padding(.horizontal)

            Spacer(minLength: 0)

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 44))
                .foregroundStyle(SchoolTheme.amber)

            Text(title).font(.title3.bold())

            HStack(spacing: 18) {
                ForEach(0..<ParentAuthManager.pinLength, id: \.self) { i in
                    Circle()
                        .strokeBorder(SchoolTheme.amber, lineWidth: 2)
                        .background(Circle().fill(i < entry.count ? SchoolTheme.amber : .clear))
                        .frame(width: 16, height: 16)
                }
            }
            .modifier(ShakeEffect(shakes: CGFloat(shakes)))
            .animation(.default, value: shakes)

            Text(message ?? (isCreating ? "Keep this PIN away from your child." : " "))
                .font(.footnote)
                .foregroundStyle(message == nil ? Color.secondary : Color.red)
                .multilineTextAlignment(.center)
                .frame(minHeight: 34)
                .padding(.horizontal)

            PINPad(
                onDigit: append,
                onDelete: { if !entry.isEmpty { entry.removeLast() } },
                biometricSymbol: showBiometricButton ? biometricSymbol : nil,
                onBiometric: { Task { await auth.authenticateWithBiometrics() } }
            )

            Spacer(minLength: 0)
        }
        .padding(.vertical)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task {
            if showBiometricButton { await auth.authenticateWithBiometrics() }
        }
    }

    private var showBiometricButton: Bool {
        !isCreating && auth.biometricsEnabled && auth.canUseBiometrics
    }

    private var biometricSymbol: String {
        switch auth.biometryType {
        case .faceID: "faceid"
        case .touchID: "touchid"
        default: "opticid"
        }
    }

    private func append(_ digit: Int) {
        guard entry.count < ParentAuthManager.pinLength else { return }
        entry.append(String(digit))
        if entry.count == ParentAuthManager.pinLength {
            // Let the last dot fill before acting.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { submit() }
        }
    }

    private func submit() {
        defer { entry = "" }
        if isCreating {
            guard let first = firstEntry else {
                firstEntry = entry
                message = nil
                return
            }
            if first == entry {
                auth.setPIN(entry)
                onFinished?()
            } else {
                firstEntry = nil
                fail("PINs didn't match. Start again.")
            }
            return
        }

        if auth.verify(entry) {
            onFinished?()
        } else if let until = auth.lockedOutUntil, until > .now {
            fail("Too many attempts. Try again at \(until.formatted(date: .omitted, time: .standard)).")
        } else {
            fail("Wrong PIN")
        }
    }

    private func fail(_ text: String) {
        message = text
        shakes += 1
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

private struct PINPad: View {
    let onDigit: (Int) -> Void
    let onDelete: () -> Void
    let biometricSymbol: String?
    let onBiometric: () -> Void

    private let rows = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    var body: some View {
        VStack(spacing: 16) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 24) {
                    ForEach(row, id: \.self) { digitKey($0) }
                }
            }
            HStack(spacing: 24) {
                if let biometricSymbol {
                    key { onBiometric() } label: { Image(systemName: biometricSymbol) }
                } else {
                    Color.clear.frame(width: 76, height: 76)
                }
                digitKey(0)
                key(action: onDelete) { Image(systemName: "delete.left") }
            }
        }
    }

    private func digitKey(_ d: Int) -> some View {
        key { onDigit(d) } label: { Text("\(d)").font(.title.weight(.medium)) }
    }

    private func key<Label: View>(action: @escaping () -> Void, @ViewBuilder label: () -> Label) -> some View {
        Button(action: action) {
            label()
                .frame(width: 76, height: 76)
                .background(Circle().fill(Color.white.opacity(0.12)))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

private struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(shakes * .pi * 4), y: 0))
    }
}
