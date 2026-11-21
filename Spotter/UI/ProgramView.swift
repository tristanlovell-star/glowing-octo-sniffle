import SwiftUI

/// The full program: every day, every exercise, with ways to tweak or redesign it.
struct ProgramView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showRedesign = false
    @State private var swapping: SwapTarget?

    struct SwapTarget: Identifiable {
        var dayID: UUID
        var item: PlannedExercise
        var id: UUID { item.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let program = store.activeProgram {
                        Card {
                            HStack {
                                Text(program.name).font(.title3.bold())
                                Spacer()
                                Pill(text: program.source == .ai ? "AI coach" : "Built-in", color: program.source == .ai ? .purple : .blue)
                            }
                            if !program.rationale.isEmpty {
                                Text(program.rationale).font(.subheadline).foregroundStyle(.secondary)
                            }
                            if let gym = store.activeGym {
                                Label(gym.name, systemImage: gym.kind == .travel ? "airplane" : "mappin.and.ellipse")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(Array(program.days.enumerated()), id: \.element.id) { index, day in
                            dayCard(program: program, day: day, isNext: index == program.nextDay % max(program.days.count, 1))
                        }
                    } else {
                        ContentUnavailableView("No program yet", systemImage: "list.bullet.clipboard",
                                               description: Text("Build one from the Today tab."))
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Program")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showRedesign = true
                    } label: {
                        Label("Redesign", systemImage: "wand.and.stars")
                    }
                    .disabled(store.activeGym == nil)
                }
            }
            .sheet(isPresented: $showRedesign) {
                RedesignSheet().environmentObject(store)
            }
            .sheet(item: $swapping) { target in
                SwapSheet(target: target).environmentObject(store)
            }
        }
    }

    private func dayCard(program: Program, day: ProgramDay, isNext: Bool) -> some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.name).font(.headline)
                    Text(day.focus).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                if isNext { Pill(text: "Next up", color: .green) }
            }
            ForEach(day.exercises) { item in
                if let exercise = store.library[item.exerciseID] {
                    Divider()
                    HStack(spacing: 12) {
                        NavigationLink {
                            ExerciseDetailView(exercise: exercise)
                        } label: {
                            HStack(spacing: 12) {
                                BundledImage(name: exercise.images.first ?? "")
                                    .frame(width: 58, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name).font(.subheadline.weight(.medium)).foregroundStyle(Color.primary)
                                    Text("\(item.prescriptionText(exercise)) · rest \(item.restSeconds)s")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !item.note.isEmpty {
                                        Text(item.note).font(.caption).foregroundStyle(.orange).multilineTextAlignment(.leading)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                        Menu {
                            Button {
                                swapping = SwapTarget(dayID: day.id, item: item)
                            } label: {
                                Label("Swap for another exercise", systemImage: "arrow.triangle.swap")
                            }
                            Button(role: .destructive) {
                                store.updateProgram(program.id) { edited in
                                    guard let d = edited.days.firstIndex(where: { $0.id == day.id }) else { return }
                                    edited.days[d].exercises.removeAll { $0.id == item.id }
                                }
                            } label: {
                                Label("Remove from program", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 36, height: 36)
                        }
                    }
                }
            }
            Button {
                store.startWorkout(day: day, program: program)
            } label: {
                Label("Start \(day.name)", systemImage: "play.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.orange)
        }
    }
}

/// Permanently replace one exercise in the program with an alternative the gym supports.
struct SwapSheet: View {
    var target: ProgramView.SwapTarget
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private var options: [Coach.Alternative] {
        guard let gym = store.activeGym, let program = store.activeProgram,
              let original = store.library[target.item.exerciseID] else { return [] }
        let used = Set(program.days.first { $0.id == target.dayID }?.exercises.map(\.exerciseID) ?? [])
        return Coach.alternatives(for: original, available: gym.available, busy: [], excluding: used,
                                  experience: .advanced, library: store.library, limit: 12)
    }

    var body: some View {
        NavigationStack {
            List(options) { option in
                Button {
                    guard let program = store.activeProgram else { return }
                    store.updateProgram(program.id) { edited in
                        guard let d = edited.days.firstIndex(where: { $0.id == target.dayID }),
                              let e = edited.days[d].exercises.firstIndex(where: { $0.id == target.item.id }) else { return }
                        edited.days[d].exercises[e].exerciseID = option.exercise.id
                        edited.days[d].exercises[e].note = ""
                    }
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        BundledImage(name: option.exercise.images.first ?? "")
                            .frame(width: 64, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.exercise.name).font(.subheadline.weight(.medium)).foregroundStyle(Color.primary)
                            Text(option.reason).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .overlay {
                if options.isEmpty {
                    ContentUnavailableView("No alternatives", systemImage: "arrow.triangle.swap",
                                           description: Text("Nothing else at this gym trains the same muscles."))
                }
            }
            .navigationTitle("Swap \(store.library.name(target.item.exerciseID))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

/// Ask for a new program, optionally telling the coach what to change.
struct RedesignSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var request = ""
    @State private var working = false
    @State private var note: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(Keychain.hasKey
                         ? "Your coach will design a new program from your profile, your gym's equipment, your training log and Apple Health data."
                         : "The built-in planner will rebuild your program from your profile and equipment. Add a Claude API key in Settings for a program designed around your training history and anything you ask for.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if Keychain.hasKey {
                    Section("Anything you want changed?") {
                        TextField("e.g. more glute work, no barbell squats, shorter Friday session", text: $request, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                if let note {
                    Section {
                        Label(note, systemImage: "info.circle").font(.footnote)
                    }
                }
                Section {
                    Button {
                        guard let gym = store.activeGym else { return }
                        working = true
                        Task {
                            note = await store.designProgram(for: gym, extraRequest: request)
                            working = false
                            if note == nil { dismiss() }
                        }
                    } label: {
                        if working {
                            HStack {
                                ProgressView()
                                Text("Designing… this can take a minute")
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Text("Design new program").frame(maxWidth: .infinity).fontWeight(.semibold)
                        }
                    }
                    .disabled(working)
                    if Keychain.hasKey {
                        Button("Use the built-in planner instead") {
                            if let gym = store.activeGym { store.buildProgram(for: gym) }
                            dismiss()
                        }
                        .disabled(working)
                    }
                } footer: {
                    Text("This replaces your current program for this gym. Your workout history is kept.")
                }
            }
            .navigationTitle("Redesign program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .interactiveDismissDisabled(working)
        }
    }
}
