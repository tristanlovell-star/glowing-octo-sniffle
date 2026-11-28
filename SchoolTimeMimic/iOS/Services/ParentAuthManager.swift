import CryptoKit
import Foundation
import LocalAuthentication
import Security

/// Guards the parent dashboard with a 4-digit PIN (stored salted + hashed in the
/// Keychain) and, optionally, Face ID / Touch ID.
///
/// On a child's own iPhone, Face ID / Touch ID recognises whoever enrolled —
/// usually the child — so biometrics are opt-in and the PIN is the real gate.
@MainActor
final class ParentAuthManager: ObservableObject {
    @Published private(set) var isUnlocked = false
    @Published private(set) var hasPIN: Bool
    @Published private(set) var lockedOutUntil: Date?
    @Published var biometricsEnabled: Bool {
        didSet { UserDefaults.standard.set(biometricsEnabled, forKey: Self.biometricsKey) }
    }

    static let pinLength = 4
    private static let biometricsKey = "parentBiometricsEnabled"
    private static let keychainAccount = "parentPIN"
    private static let maxAttempts = 5
    private static let lockoutSeconds: TimeInterval = 60

    private var failedAttempts = 0

    init() {
        hasPIN = Keychain.read(account: Self.keychainAccount) != nil
        biometricsEnabled = UserDefaults.standard.bool(forKey: Self.biometricsKey)
    }

    // MARK: PIN

    func setPIN(_ pin: String) {
        guard pin.count == Self.pinLength, pin.allSatisfy(\.isNumber) else { return }
        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        let record = salt + Self.hash(pin, salt: salt)
        Keychain.write(record, account: Self.keychainAccount)
        hasPIN = true
        isUnlocked = true
    }

    /// Returns true and unlocks if the PIN is right.
    @discardableResult
    func verify(_ pin: String) -> Bool {
        if let until = lockedOutUntil, until > .now { return false }
        guard let record = Keychain.read(account: Self.keychainAccount), record.count > 16 else { return false }
        let salt = record.prefix(16)
        let stored = record.dropFirst(16)
        if Self.hash(pin, salt: Data(salt)) == Data(stored) {
            failedAttempts = 0
            lockedOutUntil = nil
            isUnlocked = true
            return true
        }
        failedAttempts += 1
        if failedAttempts >= Self.maxAttempts {
            failedAttempts = 0
            lockedOutUntil = Date.now.addingTimeInterval(Self.lockoutSeconds)
        }
        return false
    }

    private static func hash(_ pin: String, salt: Data) -> Data {
        Data(SHA256.hash(data: salt + Data(pin.utf8)))
    }

    // MARK: Biometrics

    var biometryType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    var canUseBiometrics: Bool { biometryType != .none }

    var biometryName: String {
        switch biometryType {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        default: "Biometrics"
        }
    }

    func authenticateWithBiometrics() async {
        guard biometricsEnabled, hasPIN else { return }
        let context = LAContext()
        context.localizedFallbackTitle = "Enter PIN"
        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Open the SchoolTime parent dashboard"
            )
            if ok { isUnlocked = true }
        } catch {
            // Fall back to the PIN pad.
        }
    }

    func lock() { isUnlocked = false }
}

/// Minimal generic-password Keychain wrapper.
enum Keychain {
    private static let service = "SchoolTimeMimic"

    static func read(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func write(_ data: Data, account: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}
