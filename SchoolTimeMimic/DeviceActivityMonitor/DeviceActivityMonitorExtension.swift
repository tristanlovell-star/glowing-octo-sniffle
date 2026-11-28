import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// The system launches this extension at the start and end of every scheduled
/// school-day interval (see `ScheduleMonitor` in the app), even when the
/// SchoolTime app itself isn't running. It flips the shields on and off.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        let context = SharedStore.loadContext()
        // A parent "Paused" override (e.g. a school holiday) wins over the schedule.
        guard context.override != .forceOff else { return }
        ShieldController.applyShields()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        let context = SharedStore.loadContext()
        // "On now" keeps the shields up after the bell.
        guard context.override != .forceOn else { return }
        ShieldController.removeShields()
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
    }
}
