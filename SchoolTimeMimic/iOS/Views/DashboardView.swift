import FamilyControls
import SwiftUI

/// The parent dashboard: status + override, blocked apps, schedule, watch sync,
/// unlock history and security settings.
struct DashboardView: View {
    @EnvironmentObject private var screenTime: ScreenTimeManager
    @EnvironmentObject private var watch: PhoneSessionManager
    @EnvironmentObject private var history: UnlockHistoryStore
    @EnvironmentObject private var auth: ParentAuthManager

    let close: () -> Void

    @State private var showPicker = false
    @State private var showChangePIN = false

    var body: some View {
        NavigationStack {
            Form {
                statusSection
                blockedAppsSection
                scheduleSection
                historySection
                watchSection
                securitySection
                if let error = screenTime.lastError {
                    Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
                }
            }
            .navigationTitle("Parent Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { close() } label: { Label("Lock", systemImage: "lock.fill") }
                }
            }
            .familyActivityPicker(isPresented: $showPicker, selection: $screenTime.selection)
            .onChange(of: screenTime.selection) { screenTime.selectionDidChange() }
            .sheet(isPresented: $showChangePIN) {
                ParentGateView(
                    forceCreate: true,
                    onFinished: { showChangePIN = false },
                    onCancel: { showChangePIN = false }
                )
            }
        }
    }

    // MARK: Sections

    private var statusSection: some View {
        Section {
            TimelineView(.everyMinute) { timeline in
                let context = screenTime.context
                let active = context.isSchoolModeActive(at: timeline.date)
                HStack(spacing: 16) {
                    SchooltimeClockFace(date: timeline.date, isActive: active)
                        .frame(width: 76)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(active ? "School Mode Active" : "School Mode Off")
                            .font(.headline)
                            .foregroundStyle(active ? SchoolTheme.amber : .primary)
                        Text(context.statusDetail(at: timeline.date).capitalizedFirstLetter)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if !history.todayDuringSchool.isEmpty {
                            Text("\(history.todayDuringSchool.count) watch exit\(history.todayDuringSchool.count == 1 ? "" : "s") today")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Picker("Mode", selection: Binding(
                get: { screenTime.context.override },
                set: { screenTime.setOverride($0) }
            )) {
                ForEach(ManualOverride.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Status")
        } footer: {
            Text("\"On now\" and \"Paused\" stay in effect until you switch back to the schedule.")
        }
    }

    private var blockedAppsSection: some View {
        Section {
            Button { showPicker = true } label: {
                LabeledContent("Apps & Categories") {
                    Text(screenTime.selectionSummary)
                }
            }
            Toggle("Prevent deleting apps", isOn: Binding(
                get: { screenTime.preventsAppRemoval },
                set: { screenTime.setPreventAppRemoval($0) }
            ))
        } header: {
            Text("Blocked during School Mode")
        } footer: {
            Text("Phone, Messages from approved contacts and other always-allowed apps from Screen Time stay available.")
        }
    }

    private var scheduleSection: some View {
        Section("Schedule") {
            NavigationLink {
                ScheduleEditorView()
            } label: {
                let schedule = screenTime.context.schedule
                LabeledContent(schedule.weekdaySummary) {
                    Text(schedule.isEnabled ? schedule.timeRangeText : "Off")
                }
            }
        }
    }

    private var historySection: some View {
        Section {
            if history.events.isEmpty {
                Text("No exits from the watch face yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(history.events.prefix(3)) { UnlockEventRow(event: $0, showDate: true) }
                NavigationLink("See All (\(history.events.count))") { UnlockHistoryView() }
            }
        } header: {
            Text("Unlock History")
        }
    }

    private var watchSection: some View {
        Section {
            LabeledContent("Paired", value: watch.isPaired ? "Yes" : "No")
            LabeledContent("SchoolTime on Watch", value: watch.isWatchAppInstalled ? "Installed" : "Not installed")
            LabeledContent("Reachable now", value: watch.isReachable ? "Yes" : "No")
            if let pushed = watch.lastPushedAt {
                LabeledContent("Last synced", value: pushed.formatted(date: .omitted, time: .shortened))
            }
            Toggle("Re-lock on wrist down", isOn: Binding(
                get: { screenTime.context.relockOnWristDown },
                set: { screenTime.setRelockOnWristDown($0) }
            ))
            Button("Resend Settings to Watch") { screenTime.resendToWatch() }
            if let error = watch.lastSyncError {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
        } header: {
            Text("Apple Watch")
        } footer: {
            Text("When on, if your child holds Exit during school hours, the Schooltime face comes back the next time they lower their wrist.")
        }
    }

    private var securitySection: some View {
        Section {
            Button("Change Parent PIN") { showChangePIN = true }
            if auth.canUseBiometrics {
                Toggle("Unlock with \(auth.biometryName)", isOn: $auth.biometricsEnabled)
            }
        } header: {
            Text("Security")
        } footer: {
            if auth.canUseBiometrics {
                Text("\(auth.biometryName) recognises whoever set it up on this iPhone — usually your child. Only turn this on if your face or finger is enrolled here and theirs isn't.")
            }
        }
    }
}

struct UnlockEventRow: View {
    let event: UnlockEvent
    var showDate = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.duringScheduledHours ? "lock.open.trianglebadge.exclamationmark.fill" : "lock.open")
                .foregroundStyle(event.duringScheduledHours ? SchoolTheme.amber : .secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(showDate
                     ? event.timestamp.formatted(date: .abbreviated, time: .shortened)
                     : event.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.body.monospacedDigit())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(event.duringScheduledHours ? .orange : .secondary)
            }
            Spacer()
            Text(String(format: "%.1fs", event.holdDuration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var subtitle: String {
        if event.duringScheduledHours { return "During school hours · \(event.deviceName)" }
        if event.schoolModeWasActive { return "School Mode on by parent · \(event.deviceName)" }
        return "Outside school hours · \(event.deviceName)"
    }
}

extension String {
    var capitalizedFirstLetter: String { prefix(1).uppercased() + dropFirst() }
}
