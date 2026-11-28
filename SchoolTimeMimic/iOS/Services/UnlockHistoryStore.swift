import Foundation

/// Every Schooltime exit reported by the watch, newest first.
@MainActor
final class UnlockHistoryStore: ObservableObject {
    @Published private(set) var events: [UnlockEvent] = []

    private let key = "unlockHistory.v1"
    private let maxEvents = 500

    init() {
        events = SharedStore.load([UnlockEvent].self, key: key) ?? []
    }

    func add(_ event: UnlockEvent) {
        guard !events.contains(where: { $0.id == event.id }) else { return }
        events.append(event)
        events.sort { $0.timestamp > $1.timestamp }
        if events.count > maxEvents { events.removeLast(events.count - maxEvents) }
        save()
    }

    func clear() {
        events = []
        save()
    }

    var duringSchoolCount: Int { events.filter(\.duringScheduledHours).count }

    var todayDuringSchool: [UnlockEvent] {
        events.filter { $0.duringScheduledHours && Calendar.current.isDateInToday($0.timestamp) }
    }

    /// Events grouped by calendar day, newest day first.
    var byDay: [DayGroup] {
        let groups = Dictionary(grouping: events) { Calendar.current.startOfDay(for: $0.timestamp) }
        return groups.keys.sorted(by: >).map { DayGroup(day: $0, events: groups[$0] ?? []) }
    }

    struct DayGroup: Identifiable {
        let day: Date
        let events: [UnlockEvent]
        var id: Date { day }
    }

    private func save() { SharedStore.save(events, key: key) }
}
