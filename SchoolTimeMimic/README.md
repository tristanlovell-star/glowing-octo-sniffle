# SchoolTime Mimic

Apple's **Schooltime** only works on an Apple Watch set up with *Family Setup* (a watch managed from a parent's iPhone). SchoolTime Mimic gives a similar experience to a child whose Apple Watch is paired to **their own iPhone**:

- **Apple Watch:** a full-screen black face with a large amber ring, the time in big bold digits, the date, and a "School Mode Active" indicator. To leave it, the child has to **press and hold "Exit" for 3 seconds** while an amber progress ring fills. This stands in for Apple's "turn the Digital Crown" unlock. Every exit is logged and sent to the iPhone.
- **iPhone:** a parent dashboard behind a PIN (and Face ID / Touch ID if the parent turns it on). From there the parent picks which apps, categories and websites are **blocked during school hours**, sets the weekly schedule, pauses it or turns it on by hand, and checks the **Unlock History** from the watch.

Requires iOS 17+, watchOS 10+, Xcode 15+ (Swift 5.9).

---

## Folder structure

```
SchoolTimeMimic/
├── project.yml                         XcodeGen spec (generates SchoolTimeMimic.xcodeproj)
├── Shared/                             → iPhone app + Watch app (Models also go into both extensions)
│   ├── Models/
│   │   ├── SchoolSchedule.swift        Weekly schedule + "is it school time now?"
│   │   ├── SchoolModeContext.swift     Schedule + parent override; what gets synced to the watch
│   │   ├── UnlockEvent.swift           One manual exit from the watch face
│   │   ├── SharedStore.swift           App Group UserDefaults + Codable helpers
│   │   └── Theme.swift                 Schooltime amber
│   └── UI/
│       └── SchooltimeClockFace.swift   The ring + time + date view (watch face & iPhone preview)
├── SharedScreenTime/                   → iPhone app + DeviceActivity extension
│   └── ShieldController.swift          FamilyActivitySelection storage, ManagedSettingsStore shields
├── iOS/                                iPhone app target
│   ├── Info.plist
│   ├── SchoolTimeMimic.entitlements
│   ├── App/
│   │   ├── SchoolTimeMimicApp.swift    @main, wiring, foreground refresh, auto-lock on background
│   │   └── RootView.swift              Authorization → child home → parent area
│   ├── Services/
│   │   ├── ScreenTimeManager.swift     FamilyControls auth, selection, schedule, override, sync
│   │   ├── ScheduleMonitor.swift       DeviceActivitySchedule registration (one per weekday)
│   │   ├── PhoneSessionManager.swift   WatchConnectivity (iPhone side)
│   │   ├── UnlockHistoryStore.swift    Persisted exit log
│   │   └── ParentAuthManager.swift     PIN (salted SHA-256 in Keychain) + LocalAuthentication
│   └── Views/
│       ├── AuthorizationView.swift     "Ask a Parent to Approve"
│       ├── ChildHomeView.swift         What the child sees on the iPhone
│       ├── ParentGateView.swift        PIN pad (create / confirm / verify) + Face ID
│       ├── DashboardView.swift         Parent dashboard
│       ├── ScheduleEditorView.swift    Days + start/end time
│       └── UnlockHistoryView.swift     Exit log grouped by day
├── DeviceActivityMonitor/              DeviceActivity Monitor extension target
│   ├── DeviceActivityMonitorExtension.swift   Shields on at interval start, off at end
│   ├── Info.plist
│   └── SchoolTimeMonitor.entitlements
├── ShieldConfiguration/                Shield Configuration extension target
│   ├── ShieldConfigurationExtension.swift     Black + amber "Schooltime" block screen
│   ├── Info.plist
│   └── SchoolTimeShield.entitlements
└── Watch/                              watchOS app target (single-target watch app)
    ├── Info.plist
    ├── App/
    │   ├── SchoolTimeWatchApp.swift    @main, WatchConnectivity background task
    │   └── WatchRootView.swift         TimelineView(.everyMinute) → face / paused / idle
    ├── Services/
    │   ├── WatchSchoolModeController.swift   State + WatchConnectivity (watch side)
    │   └── ExtendedRuntimeManager.swift      WKExtendedRuntimeSession
    └── Views/
        ├── SchooltimeFaceView.swift    The full-screen replica
        ├── HoldToExitButton.swift      3-second press-and-hold with ring + haptics
        ├── ExitedView.swift            "Schooltime paused" after an exit
        └── IdleView.swift              Outside school hours
```

---

## How it works

```
 iPhone app ──updateApplicationContext(SchoolModeContext)──▶ Watch app
     ▲                                                          │
     └──────────transferUserInfo(UnlockEvent)───────────────────┘

 iPhone app ──DeviceActivityCenter.startMonitoring(Mon…Fri)──▶ system
 system ──intervalDidStart / intervalDidEnd──▶ Monitor extension ──▶ ManagedSettingsStore shields
```

- **The schedule** is registered as one repeating `DeviceActivitySchedule` per school weekday (`school.weekday.2` = Monday, and so on). The system wakes the **Monitor extension** at the start and end of each one, and the extension turns the shields on or off. The SchoolTime app doesn't need to be running for this.
- **The app selection** (`FamilyActivitySelection`) and the context are kept in the **App Group** so the extension can read them. The named `ManagedSettingsStore("schoolTime")` is shared between the app and the extension automatically.
- **Parent overrides** ("On now" / "Paused") are saved in the context. The extension respects them, and the app re-checks the shields every time it comes to the foreground in case a callback was missed.
- **The watch** receives the context through `updateApplicationContext` (only the latest state is kept). It works out school time locally, so it switches on and off on schedule even when the iPhone is out of range. `TimelineView(.everyMinute)` redraws the clock and re-checks the schedule every minute, including in Always-On mode, where the face dims.
- **Exits** are logged on the watch and sent with `transferUserInfo`. That transfer is queued, survives the iPhone app not running, and retries until delivered. Each exit records whether it was **during scheduled hours**, whether School Mode was on, how long the button was held, and the watch's name.
- **Relock:** an exit lasts only for the current school day (or the current manual "On now"). With **"Re-lock on wrist down"** on (the default), the face comes back the next time the child lowers their wrist. Apple's Schooltime behaves the same way.

---

## Setup

### 1. Generate the Xcode project

```bash
brew install xcodegen
cd SchoolTimeMimic
xcodegen generate
open SchoolTimeMimic.xcodeproj
```

In `project.yml`, change `BASE_BUNDLE_ID` (e.g. `com.yourname.schooltime`) and set `DEVELOPMENT_TEAM`. Everything below is derived from them:

| Target | Bundle ID | Type |
|---|---|---|
| SchoolTimeMimic | `BASE_BUNDLE_ID` | iOS app |
| SchoolTimeMonitor | `BASE_BUNDLE_ID.monitor` | DeviceActivity Monitor extension |
| SchoolTimeShield | `BASE_BUNDLE_ID.shield` | Shield Configuration extension |
| SchoolTimeMimicWatch | `BASE_BUNDLE_ID.watchkitapp` | watchOS app |
| *(App Group)* | `group.BASE_BUNDLE_ID` | |

<details>
<summary>Building the project by hand in Xcode instead of with XcodeGen</summary>

1. **File › New › Project › iOS App** (SwiftUI). Name it `SchoolTimeMimic`.
2. **File › New › Target › watchOS › App** → "Watch App for Existing iOS App", named `SchoolTimeMimicWatch`.
3. **File › New › Target › iOS › Device Activity Monitor Extension** → `SchoolTimeMonitor`.
4. **File › New › Target › iOS › Shield Configuration Extension** → `SchoolTimeShield`.
5. Drag the folders in and set **Target Membership**:
   - `Shared/Models/*` → all four targets
   - `Shared/UI/*` → iOS app, Watch app
   - `SharedScreenTime/*` → iOS app, SchoolTimeMonitor
   - `iOS/**`, `DeviceActivityMonitor/*`, `ShieldConfiguration/*`, `Watch/**` → their own target
6. Replace the templates' Info.plist / entitlements with the ones here, or copy their keys across (listed below).
7. Set the deployment targets to iOS 17.0 and watchOS 10.0.
</details>

### 2. Capabilities (Signing & Capabilities tab)

| Capability | iOS app | Monitor ext | Shield ext | Watch app |
|---|:-:|:-:|:-:|:-:|
| **Family Controls** | ✅ | ✅ | ✅ | — |
| **App Groups** → `group.<BASE_BUNDLE_ID>` | ✅ | ✅ | ✅ | — |
| **Background Modes** → *Session type: Mindfulness* | — | — | — | ✅ |

The entitlements files already contain these. Here they are for reference:

```xml
<!-- iOS/SchoolTimeMimic.entitlements (same in both extensions) -->
<key>com.apple.developer.family-controls</key>
<true/>
<key>com.apple.security.application-groups</key>
<array><string>$(APP_GROUP_ID)</string></array>   <!-- group.$(BASE_BUNDLE_ID) -->
```

The Watch app needs **no entitlements**: Family Controls, ManagedSettings and DeviceActivity don't exist on watchOS. Its "Background Modes" capability is just an Info.plist key (below). WatchConnectivity needs no capability on either side.

You also don't need the **iOS** "Background Modes" capability. Background work on the iPhone is done by the DeviceActivity extension, which the system launches itself, and WatchConnectivity delivers queued `transferUserInfo` items when the app next runs.

### 3. Info.plist keys

**iOS app** (`iOS/Info.plist`)

| Key | Value | Why |
|---|---|---|
| `NSFaceIDUsageDescription` | "A parent can use Face ID to open the SchoolTime parent dashboard." | Required for `LAContext` Face ID |
| `AppGroupIdentifier` | `$(APP_GROUP_ID)` | Custom key read by `AppGroup.swift` |
| `UILaunchScreen` | `{}` | |

**Monitor extension** (`DeviceActivityMonitor/Info.plist`)

| Key | Value |
|---|---|
| `NSExtension › NSExtensionPointIdentifier` | `com.apple.deviceactivity.monitor-extension` |
| `NSExtension › NSExtensionPrincipalClass` | `$(PRODUCT_MODULE_NAME).DeviceActivityMonitorExtension` |
| `AppGroupIdentifier` | `$(APP_GROUP_ID)` |

**Shield extension** (`ShieldConfiguration/Info.plist`)

| Key | Value |
|---|---|
| `NSExtension › NSExtensionPointIdentifier` | `com.apple.ManagedSettingsUI.shield-configuration-service` |
| `NSExtension › NSExtensionPrincipalClass` | `$(PRODUCT_MODULE_NAME).ShieldConfigurationExtension` |
| `AppGroupIdentifier` | `$(APP_GROUP_ID)` |

**Watch app** (`Watch/Info.plist`)

| Key | Value | Why |
|---|---|---|
| `WKApplication` | `YES` | Single-target watch app |
| `WKCompanionAppBundleIdentifier` | `$(BASE_BUNDLE_ID)` | Pairs it with the iPhone app for WatchConnectivity |
| `WKRunsIndependentlyOfCompanionApp` | `NO` | Settings come from the iPhone |
| `WKBackgroundModes` | `[ mindfulness ]` | The session type `WKExtendedRuntimeSession` uses |

---

## ⚠️ Entitlements that need Apple's approval

| Entitlement | Development | TestFlight / App Store |
|---|---|---|
| `com.apple.developer.family-controls` | Works for **development** builds with any **paid** Apple Developer Program team once you add the capability | Needs the **Family Controls (Distribution)** entitlement. Request it at **developer.apple.com/contact/request/family-controls-distribution**, **once for every bundle ID that uses it**: the app, `.monitor` and `.shield`. Approval usually takes days to a few weeks. Until it's granted, distribution provisioning profiles won't include the entitlement and uploads fail. |
| `WKBackgroundModes: mindfulness` | No approval needed | App Review expects a mindfulness session to be used for mindfulness. Keeping a lock face up is not that, so expect pushback on the **App Store**. It's fine for personal / TestFlight builds. |
| App Groups, Face ID | No approval needed | No approval needed |

Free "Personal Team" accounts **cannot** use the Family Controls capability.

---

## Running it on the child's devices

1. The child's Apple ID must be a **child (under 18) in a Family Sharing group**. `requestAuthorization(for: .child)` fails with `invalidAccountType` otherwise.
2. Install on the child's iPhone; the watch app installs on the paired watch.
3. Open SchoolTime on the iPhone and tap **Ask a Parent to Approve**. A parent or guardian signs in with *their* Apple ID on the child's phone. After that, the child can't revoke SchoolTime's Screen Time access without a parent.
4. Tap **Parent** (lock icon) and create a 4-digit PIN. Then:
   - **Apps & Categories**: pick what to block (e.g. Games, Social, Entertainment).
   - **Schedule**: Mon–Fri, 8:30 AM – 3:00 PM by default.
   - Optionally turn on **Prevent deleting apps** (`denyAppRemoval`).
5. On the **watch**, so the face stays up between wrist raises: *Settings › General › Return to Clock › SchoolTime* → turn on **Return to App**, and set *Return to Clock* to **After 1 hour**. You can also add SchoolTime to the watch Dock.

### Testing without a child account
In the Simulator or on your own (adult) iPhone, temporarily change `.child` to `.individual` in `ScreenTimeManager.requestAuthorization()`. Individual authorization uses your own Face ID / passcode, and you can revoke it in Settings. Shields only appear on a real device; the FamilyActivityPicker is empty in the Simulator.

---

## Honest limitations

- **A third-party app can't truly lock an Apple Watch.** Pressing the Digital Crown or side button still leaves the app. The 3-second hold adds friction and leaves a log entry, but it isn't a hard lock. The **exit log** is the real deterrent. The app also can't detect a Crown press, so only exits through the button are logged. The parent will see the watch face missing, though not a log entry, if the child just presses the Crown.
- **Keeping it frontmost all day:** watchOS ends a mindfulness `WKExtendedRuntimeSession` after about an hour. A new session starts each time the app becomes active again, and the *Return to App* setting above brings the app back on wrist raise. watchOS may still send the app to the background under memory pressure.
- **Face ID on the child's iPhone recognises the child**, because it's their phone. Biometrics are therefore **off by default**, and the PIN is the real parent gate. Only turn Face ID on if a parent's face (as an alternate appearance) or finger is enrolled and the child's isn't.
- **The DeviceActivity extension runs with a small memory limit (~6 MB)** and only does tiny App Group reads and shield writes, so keep it that way.
- **There is no watchOS Screen Time API**, so apps on the watch itself can't be blocked. The watch face is visual and behavioural only.
- Schedules are **same-day only** (start before end), and each interval must be ≥ 15 minutes (a DeviceActivity rule).

## CI

`.github/workflows/schooltime-build.yml` generates the project and builds every target (iOS app, both extensions, and the embedded watch app) for the Simulator on each push that touches `SchoolTimeMimic/`.
