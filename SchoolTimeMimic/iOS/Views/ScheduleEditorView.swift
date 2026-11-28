import SwiftUI

/// Edit the weekly school-hours schedule.
struct ScheduleEditorView: View {
    @EnvironmentObject private var screenTime: ScreenTimeManager
    @Environment(\.dismiss) private var dismiss

    @State private var draft = SchoolSchedule.default
    @State private var loaded = false

    var body: some View {
        Form {
            Section {
                Toggle("Turn on automatically", isOn: $draft.isEnabled)
            } footer: {
                Text("App blocking and the Schooltime watch face start and stop on this schedule.")
            }

            Section("School Days") {
                HStack(spacing: 6) {
                    ForEach(SchoolSchedule.mondayFirstWeekdays, id: \.self) { weekday in
                        let on = draft.weekdays.contains(weekday)
                        Button {
                            if on { draft.weekdays.remove(weekday) } else { draft.weekdays.insert(weekday) }
                        } label: {
                            Text(Calendar.current.veryShortWeekdaySymbols[weekday - 1])
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity, minHeight: 38)
                                .background(Circle().fill(on ? SchoolTheme.amber : Color.secondary.opacity(0.2)))
                                .foregroundStyle(on ? .black : .primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Calendar.current.weekdaySymbols[weekday - 1])
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)
            }
            .disabled(!draft.isEnabled)

            Section {
                DatePicker("Starts", selection: time(\.startHour, \.startMinute), displayedComponents: .hourAndMinute)
                DatePicker("Ends", selection: time(\.endHour, \.endMinute), displayedComponents: .hourAndMinute)
            } header: {
                Text("Hours")
            } footer: {
                if draft.isEnabled && !draft.isValid {
                    Text(draft.weekdays.isEmpty
                         ? "Pick at least one day."
                         : "The end time must be at least \(SchoolSchedule.minimumIntervalMinutes) minutes after the start.")
                        .foregroundStyle(.red)
                }
            }
            .disabled(!draft.isEnabled)

            Section {
                Button("Use Mon–Fri, 8:30 AM – 3:00 PM") { draft = .default }
            }
        }
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    screenTime.updateSchedule(draft)
                    dismiss()
                }
                .disabled(draft.isEnabled && !draft.isValid)
            }
        }
        .onAppear {
            guard !loaded else { return }
            draft = screenTime.context.schedule
            loaded = true
        }
    }

    private func time(_ hour: WritableKeyPath<SchoolSchedule, Int>, _ minute: WritableKeyPath<SchoolSchedule, Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: draft[keyPath: hour], minute: draft[keyPath: minute], second: 0, of: .now) ?? .now
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                draft[keyPath: hour] = c.hour ?? 0
                draft[keyPath: minute] = c.minute ?? 0
            }
        )
    }
}
