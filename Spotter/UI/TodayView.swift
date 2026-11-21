import SwiftUI

/// Home screen: what to do today, what the coach has noticed, and how recovery looks.
struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showSettings = false
    @State private var showTravel = false
    @State private var chosenDay: UUID?
    @State private var building = false

    private var program: Program? { store.activeProgram }

    private var day: ProgramDay? {
        guard let program else { return nil }
        return program.days.first { $0.id == chosenDay } ?? program.upcomingDay
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if store.isTravelling, let gym = store.activeGym {
                        travelBanner(gym)
                    }

                    if let program, let day {
                        nextWorkout(program: program, day: day)
                    } else {
                        Card {
                            Text("No program yet").font(.headline)
                            Text("Build one from your profile and your gym's equipment.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button(building ? "Building…" : "Build my program") {
                                guard let gym = store.activeGym else { return }
                                building = true
                                Task {
                                    await store.designProgram(for: gym)
                                    building = false
                                }
                            }
                            .buttonStyle(BigButtonStyle())
                            .disabled(building || store.activeGym == nil)
                        }
                    }

                    let insights = Coach.insights(data: store.data, library: store.library)
                    if !insights.isEmpty {
                        VStack(spacing: 8) {
                            SectionTitle("From your coach")
                            ForEach(insights) { insight in
                                InsightCard(insight: insight)
                            }
                        }
                    }

                    if let lines = store.data.health?.summaryLines, !lines.isEmpty {
                        VStack(spacing: 8) {
                            SectionTitle("Apple Health")
                            Card {
                                ForEach(lines, id: \.self) { line in
                                    Label(line, systemImage: "heart.fill")
                                        .font(.subheadline)
                                        .labelStyle(TintedIconLabel(color: .pink))
                                }
                            }
                        }
                    }

                    if !store.isTravelling {
                        Button {
                            showTravel = true
                        } label: {
                            Label("Travelling? Set up a hotel gym", systemImage: "airplane")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.orange)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(greeting)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView().environmentObject(store)
            }
            .sheet(isPresented: $showTravel) {
                TravelSetupView().environmentObject(store)
            }
        }
    }

    private var greeting: String {
        let name = store.data.profile.name
        return name.isEmpty ? "Today" : "Hi \(name)"
    }

    private func travelBanner(_ gym: Gym) -> some View {
        Card {
            HStack {
                Label("Travel mode", systemImage: "airplane").font(.headline).foregroundStyle(.blue)
                Spacer()
                Button("I'm home") { store.endTravel() }
                    .font(.subheadline.weight(.semibold))
            }
            Text("Training at \(gym.name) with a temporary plan. Your home program picks up where you left off when you're back.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func nextWorkout(program: Program, day: ProgramDay) -> some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NEXT WORKOUT").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(day.name).font(.title.bold())
                    Text(day.focus).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    ForEach(program.days) { option in
                        Button(option.name) { chosenDay = option.id }
                    }
                } label: {
                    Label("Change", systemImage: "arrow.left.arrow.right")
                        .font(.footnote.weight(.medium))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(day.exercises) { item in
                        if let exercise = store.library[item.exerciseID] {
                            VStack(alignment: .leading, spacing: 4) {
                                BundledImage(name: exercise.images.first ?? "")
                                    .frame(width: 120, height: 84)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                Text(exercise.name).font(.caption.weight(.medium)).lineLimit(2)
                                Text(item.prescriptionText(exercise)).font(.caption2).foregroundStyle(.secondary)
                            }
                            .frame(width: 120, alignment: .leading)
                        }
                    }
                }
            }

            HStack {
                Label("\(day.exercises.count) exercises", systemImage: "list.number")
                Spacer()
                Label("~\(estimatedMinutes(day)) min", systemImage: "clock")
                Spacer()
                Label(store.activeGym?.name ?? "", systemImage: "mappin.and.ellipse").lineLimit(1)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Button {
                store.startWorkout(day: day, program: program)
                chosenDay = nil
            } label: {
                Label("Start workout", systemImage: "play.fill")
            }
            .buttonStyle(BigButtonStyle())

            if let gym = store.activeGym {
                Text(ProgramBuilder.warmUpAdvice(gym: gym, goal: store.data.profile.goal))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func estimatedMinutes(_ day: ProgramDay) -> Int {
        let seconds = day.exercises.reduce(0) { total, item in
            total + item.sets * (item.restSeconds + 45) + 60
        }
        return max((seconds / 60 + 5) / 5 * 5, 10)
    }
}

struct InsightCard: View {
    var insight: Coach.Insight

    private var color: Color {
        switch insight.tone {
        case .good: return .green
        case .info: return .blue
        case .warning: return .orange
        }
    }

    private var symbol: String {
        switch insight.tone {
        case .good: return "checkmark.seal.fill"
        case .info: return "lightbulb.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(color).font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title).font(.subheadline.weight(.semibold))
                Text(insight.detail).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct TintedIconLabel: LabelStyle {
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon.foregroundStyle(color).font(.caption)
            configuration.title
        }
    }
}
