import Foundation
import FamilyControls
import ManagedSettings

extension ManagedSettingsStore.Name {
    /// App / website shields that are only on during school hours.
    static let schoolTime = Self("schoolTime")
    /// Always-on protections (e.g. stop this app being deleted).
    static let protection = Self("protection")
}

/// Turns the parent's `FamilyActivitySelection` into shields.
///
/// Used by both the main app and the DeviceActivity monitor extension, so the
/// selection lives in the App Group. `ManagedSettingsStore`s with the same name
/// are shared between an app and its extensions automatically.
enum ShieldController {
    private static let selectionKey = "familyActivitySelection.v1"
    private static let shieldsOnKey = "shieldsOn.v1"

    static let schoolStore = ManagedSettingsStore(named: .schoolTime)
    static let protectionStore = ManagedSettingsStore(named: .protection)

    // MARK: Selection persistence

    static func loadSelection() -> FamilyActivitySelection {
        SharedStore.load(FamilyActivitySelection.self, key: selectionKey) ?? FamilyActivitySelection()
    }

    static func saveSelection(_ selection: FamilyActivitySelection) {
        SharedStore.save(selection, key: selectionKey)
    }

    // MARK: Shields

    static var shieldsAreOn: Bool { AppGroup.defaults.bool(forKey: shieldsOnKey) }

    static func applyShields(_ selection: FamilyActivitySelection = loadSelection()) {
        let apps = selection.applicationTokens
        let categories = selection.categoryTokens
        let domains = selection.webDomainTokens

        schoolStore.shield.applications = apps.isEmpty ? nil : apps
        schoolStore.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        schoolStore.shield.webDomains = domains.isEmpty ? nil : domains
        schoolStore.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
        AppGroup.defaults.set(true, forKey: shieldsOnKey)
    }

    static func removeShields() {
        schoolStore.clearAllSettings()
        AppGroup.defaults.set(false, forKey: shieldsOnKey)
    }

    /// Makes the shields match what the context says *right now*.
    static func sync(with context: SchoolModeContext = SharedStore.loadContext(), at date: Date = .now) {
        if context.isSchoolModeActive(at: date) {
            applyShields()
        } else {
            removeShields()
        }
    }

    // MARK: Protection

    static var preventsAppRemoval: Bool {
        protectionStore.application.denyAppRemoval ?? false
    }

    static func setPreventAppRemoval(_ on: Bool) {
        protectionStore.application.denyAppRemoval = on ? true : nil
    }
}
