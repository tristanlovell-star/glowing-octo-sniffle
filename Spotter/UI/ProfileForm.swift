import SwiftUI

/// The "about you" questions that drive program design.
struct ProfileForm: View {
    @Binding var profile: Profile

    private let lengths = [30, 45, 60, 75, 90]

    var body: some View {
        VStack(spacing: 18) {
            Card {
                Text("About you").font(.headline)
                TextField("First name", text: $profile.name)
                    .textContentType(.givenName)
                Divider()
                HStack {
                    labelled("Age") {
                        TextField("–", value: $profile.age, format: .number).keyboardType(.numberPad)
                    }
                    labelled("Weight (kg)") {
                        TextField("–", value: $profile.weightKg, format: .number).keyboardType(.decimalPad)
                    }
                    labelled("Height (cm)") {
                        TextField("–", value: $profile.heightCm, format: .number).keyboardType(.decimalPad)
                    }
                }
            }

            Card {
                Text("Experience").font(.headline)
                Picker("Experience", selection: $profile.experience) {
                    ForEach(Experience.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(profile.experience.blurb).font(.footnote).foregroundStyle(.secondary)
            }

            Card {
                Text("Main goal").font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Goal.allCases) { goal in
                        Button {
                            profile.goal = goal
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: goal.symbol).font(.title2)
                                Text(goal.title).font(.subheadline.weight(.medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(profile.goal == goal ? Color.orange.opacity(0.2) : Color(.tertiarySystemFill),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(profile.goal == goal ? Color.orange : Color.clear, lineWidth: 2))
                            .foregroundStyle(profile.goal == goal ? Color.orange : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Card {
                Text("Schedule").font(.headline)
                Stepper("\(profile.daysPerWeek) days a week", value: $profile.daysPerWeek, in: 2...6)
                Divider()
                Text("Time per session").font(.subheadline)
                Picker("Session length", selection: $profile.sessionMinutes) {
                    ForEach(lengths, id: \.self) { Text("\($0) min").tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Card {
                Text("Injuries or things to avoid").font(.headline)
                TextField("e.g. left shoulder gets sore pressing overhead", text: $profile.limitations, axis: .vertical)
                    .lineLimit(2...5)
            }

            Card {
                Text("Anything else your coach should know").font(.headline)
                TextField("Where you're at now, what you enjoy or hate, sports you play, what you want to look or feel like…",
                          text: $profile.about, axis: .vertical)
                    .lineLimit(3...8)
            }
        }
    }

    private func labelled<Field: View>(_ title: String, @ViewBuilder field: () -> Field) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            field()
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
