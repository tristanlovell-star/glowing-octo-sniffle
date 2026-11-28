import SwiftUI

/// Every time the child held "Exit" on the watch's Schooltime face.
struct UnlockHistoryView: View {
    @EnvironmentObject private var history: UnlockHistoryStore
    @State private var confirmClear = false
    @State private var schoolHoursOnly = false

    var body: some View {
        List {
            Section {
                Toggle("Only during school hours", isOn: $schoolHoursOnly)
                LabeledContent("Exits during school hours", value: "\(history.duringSchoolCount)")
            }

            ForEach(history.byDay) { group in
                let events = schoolHoursOnly ? group.events.filter(\.duringScheduledHours) : group.events
                if !events.isEmpty {
                    Section(group.day.formatted(date: .complete, time: .omitted)) {
                        ForEach(events) { UnlockEventRow(event: $0) }
                    }
                }
            }
        }
        .overlay {
            if history.events.isEmpty {
                ContentUnavailableView(
                    "No Exits Yet",
                    systemImage: "lock.fill",
                    description: Text("Each time the Schooltime face is exited on Apple Watch, it shows up here.")
                )
            }
        }
        .navigationTitle("Unlock History")
        .toolbar {
            if !history.events.isEmpty {
                Button("Clear", role: .destructive) { confirmClear = true }
            }
        }
        .confirmationDialog("Clear all unlock history?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear History", role: .destructive) { history.clear() }
        }
    }
}
