import SwiftUI

/// Equipment help: what's in your gym, how to set each thing up, and what you can do with it.
struct EquipmentView: View {
    @EnvironmentObject private var store: AppStore
    @State private var scope = 0
    @State private var search = ""
    @State private var editingGym: Gym?

    private var gymTypes: [EquipmentType] {
        guard let gym = store.activeGym else { return [] }
        var seen: Set<EquipmentType> = []
        return gym.equipment.map(\.type).filter { seen.insert($0).inserted }
    }

    private var shown: [EquipmentType] {
        let base = scope == 0 ? gymTypes : EquipmentType.allCases
        guard !search.isEmpty else { return base }
        return base.filter { $0.displayName.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Show", selection: $scope) {
                    Text(store.activeGym?.name ?? "My gym").tag(0)
                    Text("All equipment").tag(1)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if scope == 0 && gymTypes.isEmpty {
                    Text("No equipment recorded for this gym yet. Tap Edit gym to photograph or tick off what's there.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(EquipmentType.Category.allCases) { category in
                    let types = shown.filter { $0.category == category }
                    if !types.isEmpty {
                        Section(category.rawValue) {
                            ForEach(types) { type in
                                NavigationLink {
                                    EquipmentGuideView(type: type)
                                } label: {
                                    row(type)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Find a machine")
            .navigationTitle("Equipment")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit gym") { editingGym = store.activeGym }
                        .disabled(store.activeGym == nil)
                }
            }
            .sheet(item: $editingGym) { gym in
                GymEditSheet(gym: gym).environmentObject(store)
            }
        }
    }

    private func row(_ type: EquipmentType) -> some View {
        let item = store.activeGym?.item(for: type)
        return HStack(spacing: 12) {
            if let file = item?.photoFile {
                StoredPhoto(file: file)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            } else {
                Image(systemName: type.symbol)
                    .frame(width: 52, height: 52)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .foregroundStyle(.orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(type.displayName).font(.subheadline.weight(.medium))
                if let label = item?.label, !label.isEmpty {
                    Text(label).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
    }
}

/// Everything about one kind of equipment: your photo of it, how to set it up, and exercises for it.
struct EquipmentGuideView: View {
    var type: EquipmentType
    @EnvironmentObject private var store: AppStore

    private var item: EquipmentItem? { store.activeGym?.item(for: type) }

    var body: some View {
        let guide = type.guide
        let exercises = store.library.exercises(using: type)
        ScrollView {
            VStack(spacing: 16) {
                if let file = item?.photoFile {
                    StoredPhoto(file: file)
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Card {
                    Text(type.displayName).font(.title2.bold())
                    if let item, !item.label.isEmpty {
                        Label(item.label, systemImage: "mappin.and.ellipse").font(.footnote).foregroundStyle(.secondary)
                    }
                    Text(guide.summary).font(.subheadline)
                    if let item, !item.notes.isEmpty {
                        Label(item.notes, systemImage: "note.text").font(.footnote).foregroundStyle(.secondary)
                    }
                }

                steps("Setting it up", guide.setup, symbol: "wrench.adjustable", color: .orange)
                steps("Tips", guide.tips, symbol: "lightbulb.fill", color: .green)
                steps("Common mistakes", guide.mistakes, symbol: "xmark.octagon.fill", color: .red)

                Button {
                    store.askCoach("How do I set up and use this \(type.displayName.lowercased()) for my program? Anything specific to this model I should know?",
                                   photoFile: item?.photoFile)
                } label: {
                    Label("Ask the coach about this", systemImage: "bubble.left.and.text.bubble.right")
                }
                .buttonStyle(BigButtonStyle(prominent: false))

                if !exercises.isEmpty {
                    VStack(spacing: 8) {
                        SectionTitle("What you can do with it")
                        ForEach(exercises) { exercise in
                            NavigationLink {
                                ExerciseDetailView(exercise: exercise)
                            } label: {
                                HStack(spacing: 12) {
                                    BundledImage(name: exercise.images.first ?? "")
                                        .frame(width: 64, height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exercise.name).font(.subheadline.weight(.medium)).foregroundStyle(Color.primary)
                                        Text(exercise.muscleSummary).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                                }
                                .padding(10)
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(type.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func steps(_ title: String, _ lines: [String], symbol: String, color: Color) -> some View {
        Card {
            Label(title, systemImage: symbol).font(.headline).labelStyle(TintedIconLabel(color: color))
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(color).frame(width: 5, height: 5).padding(.top, 7)
                    Text(line).font(.subheadline)
                }
            }
        }
    }
}

/// Edit an existing gym's equipment in a sheet.
struct GymEditSheet: View {
    @State var gym: Gym
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var askRebuild = false

    var body: some View {
        NavigationStack {
            ScrollView {
                GymEditor(gym: $gym).padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit gym")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let before = store.data.gyms.first { $0.id == gym.id }?.available
                        store.upsert(gym)
                        if before != gym.available { askRebuild = true } else { dismiss() }
                    }
                }
            }
            .confirmationDialog("Your equipment changed", isPresented: $askRebuild, titleVisibility: .visible) {
                Button("Redesign my program for it") {
                    Task { await store.designProgram(for: gym) }
                    dismiss()
                }
                Button("Keep my current program") { dismiss() }
            } message: {
                Text("Want the program rebuilt around the updated equipment list? Machine-busy alternatives use the new list either way.")
            }
        }
    }
}
