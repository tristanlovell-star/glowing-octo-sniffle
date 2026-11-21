import SwiftUI

/// First-run setup: AI coach key, Apple Health, your gym, about you, then the program.
struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore

    private enum Step: Int, CaseIterable { case welcome, coach, health, gym, profile, build }

    @State private var step: Step = .welcome
    @State private var gym = Gym(name: "Snap Fitness New Farm")
    @State private var profile = Profile()
    @State private var apiKey = ""
    @State private var building = false
    @State private var buildNote: String?
    @State private var healthConnected = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    switch step {
                    case .welcome: welcome
                    case .coach: coach
                    case .health: health
                    case .gym: GymEditor(gym: $gym)
                    case .profile: ProfileForm(profile: $profile)
                    case .build: build
                    }
                }
                .padding(16)
                .padding(.bottom, 90)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) { footer }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step != .welcome && !building {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            go(-1)
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                }
            }
        }
    }

    private var title: String {
        switch step {
        case .welcome: return ""
        case .coach: return "AI coach"
        case .health: return "Apple Health"
        case .gym: return "Your gym"
        case .profile: return "About you"
        case .build: return "Your program"
        }
    }

    private func go(_ delta: Int) {
        if let next = Step(rawValue: step.rawValue + delta) {
            withAnimation { step = next }
        }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 22) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
                .padding(.top, 40)
            Text("Spotter")
                .font(.largeTitle.bold())
            Text("A training program built around you and the gym you actually train in.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Card {
                feature("camera.viewfinder", "Knows your gym", "Photograph the equipment once and every session is built from what's really there.")
                feature("arrow.triangle.swap", "Machine taken? No problem", "Tell Spotter and it gives you an alternative or re-orders the session on the spot.")
                feature("chart.line.uptrend.xyaxis", "Coaches you forward", "Log weight, reps and effort; it tells you what to lift next time.")
                feature("airplane", "Travel mode", "Snap the hotel gym and get a temporary plan that keeps you on track.")
            }
        }
    }

    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }

    private var coach: some View {
        VStack(spacing: 18) {
            Card {
                Label("Turn on the AI coach", systemImage: "sparkles").font(.headline)
                Text("With a Claude API key, Spotter can recognise equipment from your photos, design your program around everything you tell it, and answer questions like a real coach.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                SecureField("sk-ant-…", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text("Create a key at console.anthropic.com › API keys. It's stored only in this iPhone's Keychain and used only to talk to Claude. Usage is billed to your Anthropic account — typically a few cents per program or photo scan.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Card {
                Label("No key? It still works", systemImage: "checkmark.seal").font(.subheadline.weight(.semibold))
                Text("Without one you tick off equipment by hand and get a solid built-in program, progression targets and machine-busy alternatives. You can add a key later in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var health: some View {
        VStack(spacing: 18) {
            Card {
                Label("Connect Apple Health", systemImage: "heart.text.square.fill")
                    .font(.headline)
                    .foregroundStyle(.pink)
                Text("Spotter reads your weight, resting heart rate, sleep, steps and workouts to judge recovery and tailor the plan, and saves each gym session to Health as a strength workout.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if healthConnected {
                    Label("Connected", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    if let lines = store.data.health?.summaryLines, !lines.isEmpty {
                        ForEach(lines, id: \.self) { Text("• \($0)").font(.footnote).foregroundStyle(.secondary) }
                    }
                } else if HealthKitManager.shared.isAvailable {
                    Button("Connect Apple Health") {
                        Task {
                            await store.connectHealth()
                            healthConnected = store.data.healthEnabled
                            if let snap = store.data.health {
                                if profile.weightKg == nil, let w = snap.weightKg { profile.weightKg = (w * 10).rounded() / 10 }
                                if profile.heightCm == nil, let h = snap.heightCm { profile.heightCm = h.rounded() }
                                if profile.age == nil { profile.age = snap.age }
                            }
                        }
                    }
                    .buttonStyle(BigButtonStyle())
                } else {
                    Text("Apple Health isn't available on this device.").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var build: some View {
        VStack(spacing: 18) {
            if building {
                Card {
                    HStack(spacing: 12) {
                        ProgressView()
                        VStack(alignment: .leading) {
                            Text("Designing your program…").font(.headline)
                            Text(Keychain.hasKey ? "Your coach is working through your profile and equipment. This can take a minute." : "Matching exercises to your equipment.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else if let program = store.data.programs.last {
                if let buildNote {
                    Card {
                        Label("Used the built-in planner", systemImage: "info.circle").font(.subheadline.weight(.semibold))
                        Text(buildNote).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                ProgramSummary(program: program)
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 8) {
            switch step {
            case .welcome:
                Button("Get started") { go(1) }.buttonStyle(BigButtonStyle())
            case .coach:
                Button(apiKey.trimmingCharacters(in: .whitespaces).isEmpty ? "Skip for now" : "Save key and continue") {
                    let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { Keychain.apiKey = trimmed }
                    go(1)
                }
                .buttonStyle(BigButtonStyle())
            case .health:
                Button(healthConnected ? "Continue" : "Skip for now") { go(1) }
                    .buttonStyle(BigButtonStyle(prominent: healthConnected))
            case .gym:
                Button(gym.equipment.isEmpty ? "Continue with no equipment" : "Continue with \(gym.equipment.count) items") { go(1) }
                    .buttonStyle(BigButtonStyle())
            case .profile:
                Button("Build my program") {
                    go(1)
                    Task { await buildProgram() }
                }
                .buttonStyle(BigButtonStyle())
            case .build:
                if !building {
                    Button("Start training") {
                        store.data.onboarded = true
                    }
                    .buttonStyle(BigButtonStyle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func buildProgram() async {
        building = true
        if gym.name.trimmingCharacters(in: .whitespaces).isEmpty { gym.name = "My gym" }
        gym.kind = .home
        store.data.profile = profile
        store.upsert(gym)
        store.data.homeGymID = gym.id
        store.data.activeGymID = gym.id
        buildNote = await store.designProgram(for: gym)
        building = false
    }
}

/// A read-only overview of a program: the rationale and each day's exercises.
struct ProgramSummary: View {
    var program: Program
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 14) {
            Card {
                HStack {
                    Text(program.name).font(.title3.bold())
                    Spacer()
                    Pill(text: program.source == .ai ? "AI coach" : "Built-in", color: program.source == .ai ? .purple : .blue)
                }
                if !program.rationale.isEmpty {
                    Text(program.rationale).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            ForEach(program.days) { day in
                Card {
                    Text(day.name).font(.headline)
                    Text(day.focus).font(.footnote).foregroundStyle(.secondary)
                    ForEach(day.exercises) { item in
                        HStack {
                            Text(store.library.name(item.exerciseID)).font(.subheadline)
                            Spacer()
                            Text(item.prescriptionText(store.library[item.exerciseID]))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
