import SwiftUI

/// How to do an exercise: demo photos, the user's own equipment, and step-by-step instructions.
struct ExerciseDetailView: View {
    var exercise: Exercise
    @EnvironmentObject private var store: AppStore

    private var gear: [EquipmentType] {
        let available = store.activeGym?.available ?? []
        return exercise.equipment(in: available) ?? exercise.requiresAny.first ?? []
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ExerciseDemo(exercise: exercise, height: 210)

                Card {
                    Text(exercise.name).font(.title2.bold())
                    HStack {
                        Pill(text: exercise.pattern.title)
                        Pill(text: exercise.muscleSummary, color: .blue)
                    }
                    if !exercise.secondaryMuscles.isEmpty {
                        Text("Also works: " + exercise.secondaryMuscles.map(\.capitalized).joined(separator: ", "))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !gear.isEmpty {
                    VStack(spacing: 8) {
                        SectionTitle("On your equipment")
                        ForEach(gear) { type in
                            NavigationLink {
                                EquipmentGuideView(type: type)
                            } label: {
                                YourEquipmentRow(type: type, item: store.activeGym?.item(for: type))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Card {
                    Text("How to do it").font(.headline)
                    ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .frame(width: 22, height: 22)
                                .background(Color.orange.opacity(0.2), in: Circle())
                                .foregroundStyle(.orange)
                            Text(step).font(.subheadline)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One row showing a piece of equipment as it appears in the user's gym.
struct YourEquipmentRow: View {
    var type: EquipmentType
    var item: EquipmentItem?

    var body: some View {
        HStack(spacing: 12) {
            if let file = item?.photoFile {
                StoredPhoto(file: file)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image(systemName: type.symbol)
                    .font(.title3)
                    .frame(width: 64, height: 64)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .foregroundStyle(.orange)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(type.displayName).font(.subheadline.weight(.semibold))
                if let item, !item.label.isEmpty {
                    Text(item.label).font(.footnote).foregroundStyle(.secondary)
                }
                if let item, !item.notes.isEmpty {
                    Text(item.notes).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Text("How to set it up").font(.caption.weight(.medium)).foregroundStyle(.orange)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
