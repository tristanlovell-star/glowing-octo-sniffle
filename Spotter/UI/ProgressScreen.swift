import SwiftUI
import Charts

/// Training history: how often, how much, and how each lift is moving.
struct ProgressScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedExercise: String?

    private var sessions: [WorkoutSession] { store.completedSessions }

    private struct WeekCount: Identifiable {
        var week: Date
        var count: Int
        var id: Date { week }
    }

    private struct LiftPoint: Identifiable {
        var date: Date
        var value: Double
        var id: Date { date }
    }

    private var weeks: [WeekCount] {
        let calendar = Calendar.current
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return [] }
        return (0..<8).reversed().compactMap { back in
            guard let start = calendar.date(byAdding: .weekOfYear, value: -back, to: thisWeek),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { return nil }
            return WeekCount(week: start, count: sessions.filter { $0.startedAt >= start && $0.startedAt < end }.count)
        }
    }

    /// Exercises with logged weighted sets, most-trained first.
    private var trackedExercises: [Exercise] {
        var counts: [String: Int] = [:]
        for session in sessions {
            for item in session.exercises where !item.sets.isEmpty { counts[item.exerciseID, default: 0] += 1 }
        }
        return counts.sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            .compactMap { store.library[$0.key] }
    }

    private func points(for exercise: Exercise) -> [LiftPoint] {
        Coach.history(for: exercise.id, in: sessions).reversed().map { entry in
            let value: Double
            if exercise.loadType == .weighted {
                value = entry.sets.map(Coach.estimatedMax).max() ?? 0
            } else {
                value = Double(entry.sets.map(\.reps).max() ?? 0)
            }
            return LiftPoint(date: entry.date, value: value)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if sessions.isEmpty {
                        ContentUnavailableView("Nothing logged yet", systemImage: "chart.line.uptrend.xyaxis",
                                               description: Text("Finish your first workout and your progress shows up here."))
                            .padding(.top, 60)
                    } else {
                        tiles
                        frequencyChart
                        liftChart
                        history
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Progress")
        }
    }

    private var tiles: some View {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recent = sessions.filter { $0.startedAt >= weekAgo }
        return HStack(spacing: 10) {
            StatTile(value: "\(sessions.count)", label: "workouts")
            StatTile(value: "\(recent.count)/\(store.data.profile.daysPerWeek)", label: "last 7 days")
            StatTile(value: volumeText(sessions.reduce(0) { $0 + $1.totalVolumeKg }), label: "lifted in total")
        }
    }

    private func volumeText(_ kg: Double) -> String {
        kg >= 10_000 ? String(format: "%.1f t", kg / 1000) : "\(Int(kg)) kg"
    }

    private var frequencyChart: some View {
        Card {
            Text("Workouts per week").font(.headline)
            Chart {
                ForEach(weeks) { week in
                    BarMark(x: .value("Week", week.week, unit: .weekOfYear), y: .value("Workouts", week.count))
                        .foregroundStyle(Color.orange)
                        .cornerRadius(4)
                }
                RuleMark(y: .value("Target", store.data.profile.daysPerWeek))
                    .foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Target").font(.caption2).foregroundStyle(.secondary)
                    }
            }
            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
            .frame(height: 160)
        }
    }

    @ViewBuilder
    private var liftChart: some View {
        let tracked = trackedExercises
        if let exercise = tracked.first(where: { $0.id == selectedExercise }) ?? tracked.first {
            let data = points(for: exercise)
            Card {
                HStack {
                    Text("Lift progress").font(.headline)
                    Spacer()
                    Menu {
                        ForEach(tracked) { option in
                            Button(option.name) { selectedExercise = option.id }
                        }
                    } label: {
                        Label(exercise.name, systemImage: "chevron.up.chevron.down")
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }
                Chart(data) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Value", point.value))
                        .foregroundStyle(Color.orange)
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Date", point.date), y: .value("Value", point.value))
                        .foregroundStyle(Color.orange)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 180)
                Text(exercise.loadType == .weighted
                     ? "Estimated one-rep max in kg — a single strength number worked out from the weight and reps of your best set each session."
                     : "Best set each session (\(exercise.loadType == .timed ? "seconds" : "reps")).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let first = data.first, let last = data.last, data.count > 1, first.value > 0 {
                    let change = (last.value - first.value) / first.value * 100
                    Label(String(format: "%+.0f%% since your first session", change),
                          systemImage: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(change >= 0 ? Color.green : Color.orange)
                }
            }
        }
    }

    private var history: some View {
        VStack(spacing: 8) {
            SectionTitle("History")
            ForEach(sessions) { session in
                NavigationLink {
                    SessionDetailView(session: session)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.dayName).font(.subheadline.weight(.semibold)).foregroundStyle(Color.primary)
                            Text("\(session.startedAt.shortDay) · \(session.gymName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(session.durationMinutes) min").font(.subheadline.monospacedDigit()).foregroundStyle(Color.primary)
                            Text("\(session.totalSets) sets").font(.caption).foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct StatTile: View {
    var value: String
    var label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.bold().monospacedDigit()).minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct SessionDetailView: View {
    var session: WorkoutSession
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        List {
            Section {
                LabeledContent("Date", value: session.startedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Gym", value: session.gymName)
                LabeledContent("Duration", value: "\(session.durationMinutes) min")
                LabeledContent("Volume", value: "\(Int(session.totalVolumeKg)) kg")
                if let effort = session.overallEffort { LabeledContent("Overall effort", value: "\(effort)/10") }
                if let heartRate = session.averageHeartRate {
                    LabeledContent("Average heart rate", value: String(format: "%.0f bpm", heartRate))
                }
                if session.savedToHealth { Label("Saved to Apple Health", systemImage: "heart.fill").foregroundStyle(.pink) }
            }
            ForEach(session.exercises) { item in
                Section {
                    if item.sets.isEmpty {
                        Text("Skipped").foregroundStyle(.secondary)
                    }
                    ForEach(Array(item.sets.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            Text("Set \(index + 1)").foregroundStyle(.secondary)
                            Spacer()
                            Text(store.library[item.exerciseID]?.loadType == .weighted
                                 ? "\(Coach.format(set.weightKg)) kg × \(set.reps)" : "\(set.reps)")
                                .monospacedDigit()
                            Text(set.effort.title).font(.caption).foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                        }
                    }
                } header: {
                    Text(store.library.name(item.exerciseID))
                } footer: {
                    if let replaced = item.replacedExerciseID {
                        Text("Swapped in for \(store.library.name(replaced))")
                    }
                }
            }
            if !session.notes.isEmpty {
                Section("Notes") { Text(session.notes) }
            }
            Section {
                Button("Delete workout", role: .destructive) { confirmDelete = true }
            }
        }
        .navigationTitle(session.dayName)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this workout?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                store.data.sessions.removeAll { $0.id == session.id }
                dismiss()
            }
        }
    }
}
