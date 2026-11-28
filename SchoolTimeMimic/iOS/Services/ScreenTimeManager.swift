import Combine
import FamilyControls
import Foundation
import ManagedSettings

/// Owns Family Controls authorization, the parent's app selection, and the
/// School Mode context; keeps shields, DeviceActivity and the watch in sync.
@MainActor
final class ScreenTimeManager: ObservableObject {
    @Published private(set) var authorizationStatus: AuthorizationStatus
    @Published var selection: FamilyActivitySelection
    @Published private(set) var context: SchoolModeContext
    @Published private(set) var preventsAppRemoval: Bool
    @Published var lastError: String?

    private let center = AuthorizationCenter.shared
    private let watch: PhoneSessionManager
    private var cancellables = Set<AnyCancellable>()

    init(watch: PhoneSessionManager) {
        self.watch = watch
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        selection = ShieldController.loadSelection()
        context = SharedStore.loadContext()
        preventsAppRemoval = ShieldController.preventsAppRemoval

        center.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.authorizationStatus = $0 }
            .store(in: &cancellables)

        // The watch can ask for the latest context when it launches.
        watch.contextProvider = { SharedStore.loadContext() }
    }

    var isAuthorized: Bool { authorizationStatus == .approved }
    var isSchoolModeActive: Bool { context.isSchoolModeActive() }

    var selectionSummary: String {
        let apps = selection.applicationTokens.count
        let categories = selection.categoryTokens.count
        let sites = selection.webDomainTokens.count
        if apps + categories + sites == 0 { return "Nothing selected" }
        var parts: [String] = []
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        if categories > 0 { parts.append("\(categories) categor\(categories == 1 ? "y" : "ies")") }
        if sites > 0 { parts.append("\(sites) website\(sites == 1 ? "" : "s")") }
        return parts.joined(separator: ", ")
    }

    // MARK: Authorization

    /// On a child's device this shows Apple's sheet asking a parent / guardian in
    /// the Family Sharing group to approve with *their* Apple ID.
    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(for: .child)
            lastError = nil
            applyEverything()
        } catch {
            lastError = Self.describe(error)
        }
    }

    // MARK: Parent changes

    func selectionDidChange() {
        ShieldController.saveSelection(selection)
        ShieldController.sync(with: context)
    }

    func updateSchedule(_ schedule: SchoolSchedule) {
        context.schedule = schedule
        commit()
    }

    func setOverride(_ override: ManualOverride) {
        context.override = override
        commit()
    }

    func setRelockOnWristDown(_ on: Bool) {
        context.relockOnWristDown = on
        commit()
    }

    func setPreventAppRemoval(_ on: Bool) {
        ShieldController.setPreventAppRemoval(on)
        preventsAppRemoval = ShieldController.preventsAppRemoval
    }

    // MARK: Sync

    /// Call on launch / when returning to the foreground: corrects the shields
    /// in case a DeviceActivity callback was missed, and refreshes the watch.
    func refresh() {
        context = SharedStore.loadContext()
        if isAuthorized { ShieldController.sync(with: context) }
        watch.push(context)
    }

    func resendToWatch() {
        context.updatedAt = .now
        SharedStore.saveContext(context)
        watch.push(context)
    }

    private func commit() {
        context.updatedAt = .now
        applyEverything()
    }

    private func applyEverything() {
        SharedStore.saveContext(context)
        if isAuthorized {
            do {
                try ScheduleMonitor.apply(context.schedule)
                lastError = nil
            } catch {
                lastError = Self.describe(error)
            }
            ShieldController.sync(with: context)
        }
        watch.push(context)
    }

    private static func describe(_ error: Error) -> String {
        if let fc = error as? FamilyControlsError {
            switch fc {
            case .restricted: return "Screen Time is restricted on this device."
            case .unavailable: return "Family Controls isn't available on this device."
            case .invalidAccountType: return "This iPhone must be signed in with a child's Apple ID that is part of a Family Sharing group."
            case .invalidArgument: return "Invalid Family Controls request."
            case .authorizationConflict: return "Another app is already managing Screen Time on this device."
            case .authorizationCanceled: return "A parent cancelled the approval."
            case .networkError: return "Couldn't reach Apple to verify the parent. Check the internet connection."
            case .authenticationMethodUnavailable: return "Set a device passcode first, then try again."
            @unknown default: return fc.localizedDescription
            }
        }
        return error.localizedDescription
    }
}
