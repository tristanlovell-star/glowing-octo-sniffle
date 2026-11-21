import SwiftUI
import UIKit

/// The screen you use in the gym: one exercise at a time, with demo photos, a target from the coach,
/// quick set logging, a rest timer, and the "machine busy" escape hatch.
struct WorkoutView: View {
    @EnvironmentObject private var store: AppStore

    @State private var current = 0
    @State private var weight: Double = 0
    @State private var reps = 10
    @State private var effort: Effort = .moderate
    @State private var restEnds: Date?
    @State private var showBusy = false
    @State private var showDetail = false
    @State private var showFinish = false
    @State private var confirmDiscard = false

    private var session: WorkoutSession? { store.data.activeSession }
    private var gym: Gym? { store.data.gyms.first { $0.id == session?.gymID } ?? store.activeGym }

    private var item: SessionExercise? {
        guard let session, session.exercises.indices.contains(current) else { return nil }
        return session.exercises[current]
    }

    var body: some View {
        NavigationStack {
            Group {
                if let session, let item, let exercise = store.library[item.exerciseID] {
                    content(session: session, item: item, exercise: exercise)
                } else {
                    ContentUnavailableView("No exercises", systemImage: "figure.strengthtraining.traditional")
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(session?.dayName ?? "Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .destructive) { confirmDiscard = true }
                }
                ToolbarItem(placement: .principal) {
                    if let session {
                        TimelineView(.periodic(from: .now, by: 30)) { _ in
                            VStack(spacing: 0) {
                                Text(session.dayName).font(.subheadline.weight(.semibold))
                                Text("\(session.durationMinutes) min").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") { showFinish = true }.fontWeight(.semibold)
                }
            }
            .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard workout", role: .destructive) { store.discardWorkout() }
                Button("Keep going", role: .cancel) {}
            } message: {
                Text("Sets you've logged in this session will be lost.")
            }
        }
        .sheet(isPresented: $showBusy) {
            if let item, let exercise = store.library[item.exerciseID] {
                BusySheet(index: current, exercise: exercise) { newIndex in
                    select(newIndex)
                }
                .environmentObject(store)
            }
        }
        .sheet(isPresented: $showDetail) {
            if let item, let exercise = store.library[item.exerciseID] {
                NavigationStack {
                    ExerciseDetailView(exercise: exercise)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) { Button("Done") { showDetail = false } }
                        }
                }
                .environmentObject(store)
            }
        }
        .sheet(isPresented: $showFinish) {
            FinishSheet().environmentObject(store)
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            if let session, let firstOpen = session.exercises.firstIndex(where: { !$0.isDone }) {
                select(firstOpen)
            } else {
                select(0)
            }
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .task {
            // Lets screenshots open straight onto a sheet (demo mode only).
            guard let screen = store.demoScreen else { return }
            try? await Task.sleep(nanoseconds: 600_000_000)
            if screen == "busy" { showBusy = true }
            if screen == "detail" { showDetail = true }
        }
    }

    // MARK: Main content

    private func content(session: WorkoutSession, item: SessionExercise, exercise: Exercise) -> some View {
        let target = Coach.target(for: item, exercise: exercise, sessions: store.data.sessions)
        return ScrollView {
            VStack(spacing: 14) {
                progressDots(session)

                if let restEnds {
                    RestBanner(ends: restEnds) { self.restEnds = nil }
                }

                Card {
                    HStack(alignment: .firstTextBaseline) {
                        Text(exercise.name).font(.title2.bold())
                        Spacer()
                        Text(item.prescriptionText(exercise))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.orange)
                    }
                    if let replaced = item.replacedExerciseID {
                        Label("In place of \(store.library.name(replaced))", systemImage: "arrow.triangle.swap")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        showDetail = true
                    } label: {
                        ExerciseDemo(exercise: exercise)
                    }
                    .buttonStyle(.plain)

                    if let gym, let gear = exercise.equipment(in: gym.available), !gear.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(gear) { type in
                                    EquipmentChip(type: type, item: gym.item(for: type))
                                }
                            }
                        }
                    }
                    if !item.note.isEmpty {
                        Label(item.note, systemImage: "quote.bubble")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        Button {
                            showBusy = true
                        } label: {
                            Label("Machine busy", systemImage: "person.2.slash")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(Color.red.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .foregroundStyle(.red)
                        }
                        Button {
                            showDetail = true
                        } label: {
                            Label("How to", systemImage: "questionmark.circle")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .foregroundStyle(Color.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Card {
                    Label(target.headline, systemImage: "target")
                        .font(.headline)
                    Text(target.detail).font(.footnote).foregroundStyle(.secondary)
                }

                setLogger(item: item, exercise: exercise)

                queue(session)
            }
            .padding(16)
        }
    }

    private func progressDots(_ session: WorkoutSession) -> some View {
        HStack(spacing: 5) {
            ForEach(Array(session.exercises.enumerated()), id: \.element.id) { index, entry in
                Capsule()
                    .fill(entry.isDone ? Color.green : (index == current ? Color.orange : Color(.systemFill)))
                    .frame(height: 5)
            }
        }
    }

    // MARK: Logging

    private func setLogger(item: SessionExercise, exercise: Exercise) -> some View {
        Card {
            ForEach(Array(item.sets.enumerated()), id: \.element.id) { index, set in
                HStack {
                    Text("Set \(index + 1)").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text(describe(set, exercise)).font(.subheadline.monospacedDigit().weight(.medium))
                    Pill(text: set.effort.title, color: color(set.effort))
                    Button {
                        store.data.activeSession?.exercises[current].sets.removeAll { $0.id == set.id }
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                Divider()
            }

            Text(item.isDone ? "Extra set" : "Set \(item.sets.count + 1) of \(item.targetSets)")
                .font(.headline)

            HStack(spacing: 12) {
                if exercise.loadType == .weighted {
                    NumberStepper(title: "kg", value: $weight, step: Coach.increment(for: exercise, at: weight), decimals: true)
                }
                NumberStepper(title: exercise.loadType == .timed ? "seconds" : "reps",
                              value: Binding(get: { Double(reps) }, set: { reps = max(Int($0), 0) }),
                              step: exercise.loadType == .timed ? 5 : 1, decimals: false)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("How did it feel?").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(Effort.allCases) { option in
                        Button {
                            effort = option
                        } label: {
                            VStack(spacing: 1) {
                                Text(option.title).font(.subheadline.weight(.semibold))
                                Text(option.detail).font(.system(size: 9))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(effort == option ? color(option).opacity(0.22) : Color(.tertiarySystemFill),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .foregroundStyle(effort == option ? color(option) : Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                logSet(item: item)
            } label: {
                Label("Log set", systemImage: "checkmark")
            }
            .buttonStyle(BigButtonStyle())

            if !item.isDone {
                Button("Skip this exercise") {
                    store.data.activeSession?.exercises[current].skipped = true
                    advance()
                }
                .font(.footnote)
                .frame(maxWidth: .infinity)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func describe(_ set: LoggedSet, _ exercise: Exercise) -> String {
        switch exercise.loadType {
        case .timed: return "\(set.reps) sec"
        case .bodyweight: return set.weightKg > 0 ? "+\(Coach.format(set.weightKg)) kg × \(set.reps)" : "\(set.reps) reps"
        case .weighted: return "\(Coach.format(set.weightKg)) kg × \(set.reps)"
        }
    }

    private func color(_ effort: Effort) -> Color {
        switch effort {
        case .easy: return .green
        case .moderate: return .blue
        case .hard: return .orange
        case .maxed: return .red
        }
    }

    private func logSet(item: SessionExercise) {
        guard store.data.activeSession?.exercises.indices.contains(current) == true else { return }
        let logged = LoggedSet(weightKg: max(weight, 0), reps: reps, effort: effort)
        store.data.activeSession?.exercises[current].sets.append(logged)
        store.data.activeSession?.exercises[current].skipped = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        restEnds = Date().addingTimeInterval(TimeInterval(item.restSeconds))
        if store.data.activeSession?.exercises[current].isDone == true {
            advance()
        }
    }

    /// Moves to the next unfinished exercise, wrapping round to any that were left for later.
    private func advance() {
        guard let session else { return }
        let indices = session.exercises.indices
        let order = Array(indices.dropFirst(current + 1)) + Array(indices.prefix(current))
        if let next = order.first(where: { !session.exercises[$0].isDone }) {
            select(next)
        } else if session.exercises.allSatisfy(\.isDone) {
            showFinish = true
        }
    }

    private func select(_ index: Int) {
        guard let session, session.exercises.indices.contains(index) else { return }
        current = index
        let entry = session.exercises[index]
        guard let exercise = store.library[entry.exerciseID] else { return }
        effort = .moderate
        if let last = entry.sets.last {
            weight = last.weightKg
            reps = last.reps
            return
        }
        let target = Coach.target(for: entry, exercise: exercise, sessions: store.data.sessions)
        weight = target.weightKg ?? 0
        reps = max(target.repGoal, 1)
    }

    // MARK: Queue

    private func queue(_ session: WorkoutSession) -> some View {
        VStack(spacing: 8) {
            SectionTitle("This session")
            VStack(spacing: 0) {
                ForEach(Array(session.exercises.enumerated()), id: \.element.id) { index, entry in
                    Button {
                        select(index)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: entry.skipped && entry.sets.isEmpty ? "forward.circle"
                                  : (entry.isDone ? "checkmark.circle.fill" : (index == current ? "play.circle.fill" : "circle")))
                                .foregroundStyle(entry.isDone ? Color.green : (index == current ? Color.orange : Color.secondary))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(store.library.name(entry.exerciseID))
                                    .font(.subheadline.weight(index == current ? .semibold : .regular))
                                    .foregroundStyle(Color.primary)
                                Text("\(entry.sets.count)/\(entry.targetSets) sets")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if index < session.exercises.count - 1 { Divider().padding(.leading, 46) }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

// MARK: - Pieces

private struct EquipmentChip: View {
    var type: EquipmentType
    var item: EquipmentItem?

    var body: some View {
        HStack(spacing: 8) {
            if let file = item?.photoFile {
                StoredPhoto(file: file)
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            } else {
                Image(systemName: type.symbol).foregroundStyle(.orange)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(type.displayName).font(.caption.weight(.semibold))
                if let label = item?.label, !label.isEmpty {
                    Text(label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct NumberStepper: View {
    var title: String
    @Binding var value: Double
    var step: Double
    var decimals: Bool

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Button {
                    value = max(value - step, 0)
                } label: {
                    Image(systemName: "minus").frame(width: 40, height: 48)
                }
                TextField("0", value: $value, format: .number.precision(.fractionLength(0...(decimals ? 2 : 0))))
                    .keyboardType(decimals ? .decimalPad : .numberPad)
                    .multilineTextAlignment(.center)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .frame(maxWidth: .infinity)
                Button {
                    value += step
                } label: {
                    Image(systemName: "plus").frame(width: 40, height: 48)
                }
            }
            .buttonStyle(.plain)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct RestBanner: View {
    var ends: Date
    var onSkip: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = Int(ends.timeIntervalSince(context.date).rounded(.up))
            HStack {
                Image(systemName: remaining > 0 ? "timer" : "bolt.fill")
                if remaining > 0 {
                    Text("Rest \(remaining / 60):\(String(format: "%02d", remaining % 60))")
                        .font(.headline.monospacedDigit())
                } else {
                    Text("Rest over — next set").font(.headline)
                }
                Spacer()
                Button(remaining > 0 ? "Skip" : "Dismiss", action: onSkip)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(remaining > 0 ? Color.blue.opacity(0.16) : Color.green.opacity(0.2),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(remaining > 0 ? Color.blue : Color.green)
        }
    }
}

// MARK: - Machine busy

/// What to do when the equipment for the current exercise is taken:
/// swap to an alternative, do something else first, or skip it.
struct BusySheet: View {
    var index: Int
    var exercise: Exercise
    var onSelect: (Int) -> Void

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var taken: Set<EquipmentType> = []
    @State private var loaded = false

    private var gym: Gym? { store.activeGym }
    private var gear: [EquipmentType] {
        exercise.equipment(in: gym?.available ?? []) ?? exercise.requiresAny.first ?? []
    }

    private var busy: Set<EquipmentType> {
        (store.data.activeSession?.busyNow() ?? []).union(taken)
    }

    private var alternatives: [Coach.Alternative] {
        guard let gym, let session = store.data.activeSession else { return [] }
        let inSession = Set(session.exercises.map(\.exerciseID))
        return Coach.alternatives(for: exercise, available: gym.available, busy: busy, excluding: inSession,
                                  experience: store.data.profile.experience, library: store.library)
    }

    /// The exercise to do in the meantime if you'd rather wait for the machine.
    private var meanwhile: Int? {
        guard let gym, var session = store.data.activeSession else { return nil }
        for type in taken { session.busy[type.rawValue] = Date() }
        return Coach.nextFreeExercise(in: session, after: index, available: gym.available, library: store.library)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if gear.count > 1 {
                        Card {
                            Text("What's taken?").font(.headline)
                            HStack {
                                ForEach(gear) { type in
                                    Button {
                                        if taken.contains(type) { taken.remove(type) } else { taken.insert(type) }
                                    } label: {
                                        Text(type.displayName)
                                            .font(.subheadline.weight(.medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(taken.contains(type) ? Color.red.opacity(0.18) : Color(.tertiarySystemFill), in: Capsule())
                                            .foregroundStyle(taken.contains(type) ? Color.red : Color.primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if let meanwhile, let session = store.data.activeSession {
                        let other = session.exercises[meanwhile]
                        VStack(spacing: 8) {
                            SectionTitle("Re-order the session")
                            Button {
                                comeBackLater(doFirst: meanwhile)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "arrow.uturn.down.circle.fill").font(.title2).foregroundStyle(.blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Do \(store.library.name(other.exerciseID)) now")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.primary)
                                        Text("Its equipment is free. You'll come back to \(exercise.name) straight after.")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(14)
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(spacing: 8) {
                        SectionTitle("Or swap it for")
                        if alternatives.isEmpty {
                            Card {
                                Text("Nothing else at this gym trains the same muscles with free equipment right now. Do another exercise first, or skip this one today.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(alternatives) { option in
                            Button {
                                swap(to: option.exercise)
                            } label: {
                                HStack(spacing: 12) {
                                    BundledImage(name: option.exercise.images.first ?? "")
                                        .frame(width: 76, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.exercise.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.primary)
                                        Text(option.reason)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "arrow.triangle.swap").foregroundStyle(.orange)
                                }
                                .padding(10)
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button("Skip \(exercise.name) today") {
                        markBusy()
                        store.data.activeSession?.exercises[index].skipped = true
                        let next = store.data.activeSession?.exercises.firstIndex { !$0.isDone } ?? index
                        onSelect(next)
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("\(gear.first?.displayName ?? exercise.name) busy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("It's free now") { dismiss() } }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            guard !loaded else { return }
            loaded = true
            taken = Set(Coach.likelyBusy(for: exercise, available: gym?.available ?? []))
        }
    }

    private func markBusy() {
        for type in taken { store.data.activeSession?.busy[type.rawValue] = Date() }
    }

    private func swap(to replacement: Exercise) {
        markBusy()
        guard var session = store.data.activeSession, session.exercises.indices.contains(index) else { return }
        let original = session.exercises[index]
        let prescription = ProgramBuilder.prescription(for: replacement, profile: store.data.profile)
        let sameKind = replacement.loadType == exercise.loadType && replacement.compound == exercise.compound
        var entry = SessionExercise(
            exerciseID: replacement.id,
            replacedExerciseID: original.replacedExerciseID ?? original.exerciseID,
            targetSets: max(original.targetSets - original.sets.count, 1),
            repMin: sameKind ? original.repMin : prescription.repMin,
            repMax: sameKind ? original.repMax : prescription.repMax,
            restSeconds: sameKind ? original.restSeconds : prescription.restSeconds)
        entry.note = ""
        if original.sets.isEmpty {
            session.exercises[index] = entry
            store.data.activeSession = session
            onSelect(index)
        } else {
            // Keep what was already done on the original, and finish the remaining sets on the swap.
            session.exercises[index].targetSets = original.sets.count
            session.exercises.insert(entry, at: index + 1)
            store.data.activeSession = session
            onSelect(index + 1)
        }
        dismiss()
    }

    private func comeBackLater(doFirst other: Int) {
        markBusy()
        guard var session = store.data.activeSession, session.exercises.indices.contains(index),
              session.exercises.indices.contains(other) else { return }
        let otherID = session.exercises[other].id
        let waiting = session.exercises.remove(at: index)
        let otherIndex = session.exercises.firstIndex { $0.id == otherID } ?? 0
        session.exercises.insert(waiting, at: min(otherIndex + 1, session.exercises.count))
        store.data.activeSession = session
        onSelect(session.exercises.firstIndex { $0.id == otherID } ?? 0)
        dismiss()
    }
}

// MARK: - Finish

struct FinishSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var overall = 7.0
    @State private var notes = ""
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                if let session = store.data.activeSession {
                    Section {
                        LabeledContent("Time", value: "\(session.durationMinutes) min")
                        LabeledContent("Sets logged", value: "\(session.totalSets)")
                        LabeledContent("Volume lifted", value: "\(Int(session.totalVolumeKg)) kg")
                        let open = session.exercises.filter { !$0.isDone }.count
                        if open > 0 {
                            Label("\(open) exercise\(open == 1 ? "" : "s") not finished", systemImage: "exclamationmark.circle")
                                .foregroundStyle(.orange)
                        }
                    }
                }
                Section("Overall effort: \(Int(overall))/10") {
                    Slider(value: $overall, in: 1...10, step: 1) {
                        Text("Effort")
                    } minimumValueLabel: {
                        Text("Easy").font(.caption)
                    } maximumValueLabel: {
                        Text("All out").font(.caption)
                    }
                }
                Section("Notes for your coach") {
                    TextField("Anything that felt off, sore, or great", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    Button {
                        Task { await finish() }
                    } label: {
                        if saving {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Save workout").frame(maxWidth: .infinity).fontWeight(.semibold)
                        }
                    }
                    .disabled(saving)
                }
            }
            .navigationTitle("Finish workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Back") { dismiss() } }
            }
        }
    }

    private func finish() async {
        saving = true
        guard let session = store.finishWorkout(overallEffort: Int(overall), notes: notes) else {
            dismiss()
            return
        }
        if store.data.healthEnabled, let end = session.endedAt {
            let heartRate = await HealthKitManager.shared.averageHeartRate(from: session.startedAt, to: end)
            var saved = false
            if store.data.saveWorkoutsToHealth {
                saved = await HealthKitManager.shared.save(session)
            }
            store.updateSession(session.id) { stored in
                stored.averageHeartRate = heartRate
                stored.savedToHealth = saved
            }
            await store.refreshHealth()
        }
    }
}
