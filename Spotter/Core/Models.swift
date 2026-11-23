import Foundation

// MARK: - Gym

struct EquipmentItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var type: EquipmentType
    /// What it looks like in this gym, e.g. "Life Fitness chest press, by the mirrors".
    var label: String = ""
    var notes: String = ""
    var photoFile: String?

    var title: String { label.isEmpty ? type.displayName : label }
}

struct Gym: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case home, travel }

    var id = UUID()
    var name: String
    var kind: Kind = .home
    var equipment: [EquipmentItem] = []
    var createdAt = Date()

    /// Everything you can train with here, including what's implied (adjustable bench = flat bench).
    var available: Set<EquipmentType> { Set(equipment.map(\.type)).expanded }

    func item(for type: EquipmentType) -> EquipmentItem? {
        equipment.first { $0.type == type && $0.photoFile != nil } ?? equipment.first { $0.type == type }
    }

    mutating func add(_ type: EquipmentType) {
        guard !equipment.contains(where: { $0.type == type }) else { return }
        equipment.append(EquipmentItem(type: type))
    }

    mutating func remove(_ type: EquipmentType) {
        equipment.removeAll { $0.type == type }
    }
}

// MARK: - Profile

enum Experience: String, Codable, CaseIterable, Identifiable {
    case beginner, intermediate, advanced
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var blurb: String {
        switch self {
        case .beginner: return "New to the gym, or back after a long break"
        case .intermediate: return "Training consistently for 6+ months"
        case .advanced: return "Years of structured lifting"
        }
    }
}

enum Goal: String, Codable, CaseIterable, Identifiable {
    case buildMuscle, loseFat, getStronger, generalFitness
    var id: String { rawValue }
    var title: String {
        switch self {
        case .buildMuscle: return "Build muscle"
        case .loseFat: return "Lose fat"
        case .getStronger: return "Get stronger"
        case .generalFitness: return "General fitness"
        }
    }
    /// Reads naturally after "for", e.g. "a plan for building muscle".
    var phrase: String {
        switch self {
        case .buildMuscle: return "building muscle"
        case .loseFat: return "losing fat"
        case .getStronger: return "getting stronger"
        case .generalFitness: return "general fitness"
        }
    }
    var symbol: String {
        switch self {
        case .buildMuscle: return "figure.strengthtraining.traditional"
        case .loseFat: return "flame.fill"
        case .getStronger: return "bolt.fill"
        case .generalFitness: return "heart.fill"
        }
    }
}

struct Profile: Codable, Hashable {
    var name = ""
    var age: Int?
    var weightKg: Double?
    var heightCm: Double?
    var experience: Experience = .beginner
    var goal: Goal = .generalFitness
    var daysPerWeek = 3
    var sessionMinutes = 45
    /// Injuries or movements to avoid, in the user's own words.
    var limitations = ""
    /// Anything else: current fitness, sports, what they enjoy, what they hate.
    var about = ""
}

// MARK: - Program

struct PlannedExercise: Codable, Identifiable, Hashable {
    var id = UUID()
    var exerciseID: String
    var sets: Int
    var repMin: Int
    var repMax: Int
    var restSeconds: Int
    var note: String = ""
}

struct ProgramDay: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var focus: String
    var exercises: [PlannedExercise]
}

struct Program: Codable, Identifiable, Hashable {
    enum Source: String, Codable { case rules, ai }

    var id = UUID()
    var name: String
    var gymID: UUID
    var createdAt = Date()
    var days: [ProgramDay]
    var rationale: String = ""
    var source: Source = .rules
    /// Index of the day to do next; wraps around.
    var nextDay = 0

    var upcomingDay: ProgramDay? {
        days.isEmpty ? nil : days[nextDay % days.count]
    }
}

// MARK: - Workout log

struct LoggedSet: Codable, Identifiable, Hashable {
    var id = UUID()
    var weightKg: Double
    /// Reps, or seconds for timed holds.
    var reps: Int
    var effort: Effort
    var at = Date()
    /// The song playing in Apple Music when the set was logged, if any.
    var track: TrackInfo?
}

enum Effort: Int, Codable, CaseIterable, Identifiable {
    case easy = 6, moderate = 7, hard = 9, maxed = 10
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .easy: return "Easy"
        case .moderate: return "Solid"
        case .hard: return "Hard"
        case .maxed: return "Max"
        }
    }
    var detail: String {
        switch self {
        case .easy: return "4+ reps left"
        case .moderate: return "2–3 reps left"
        case .hard: return "1 rep left"
        case .maxed: return "Nothing left"
        }
    }
}

struct SessionExercise: Codable, Identifiable, Hashable {
    var id = UUID()
    var exerciseID: String
    /// Set when this replaced the programmed exercise (machine busy, travel, etc.).
    var replacedExerciseID: String?
    var targetSets: Int
    var repMin: Int
    var repMax: Int
    var restSeconds: Int
    var note: String = ""
    var sets: [LoggedSet] = []
    var skipped = false

    var isDone: Bool { skipped || sets.count >= targetSets }
    var volumeKg: Double { sets.reduce(0) { $0 + $1.weightKg * Double($1.reps) } }
}

struct WorkoutSession: Codable, Identifiable, Hashable {
    var id = UUID()
    var programID: UUID?
    var dayName: String
    var gymID: UUID
    var gymName: String
    var startedAt = Date()
    var endedAt: Date?
    var exercises: [SessionExercise]
    /// Equipment reported busy, with the time it was reported.
    var busy: [String: Date] = [:]
    var overallEffort: Int?
    var notes = ""
    var averageHeartRate: Double?
    var savedToHealth = false

    var durationMinutes: Int {
        Int((endedAt ?? Date()).timeIntervalSince(startedAt) / 60)
    }
    var totalVolumeKg: Double { exercises.reduce(0) { $0 + $1.volumeKg } }
    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets.count } }

    /// Equipment still considered busy (reports expire after 12 minutes).
    func busyNow(at date: Date = Date()) -> Set<EquipmentType> {
        Set(busy.compactMap { key, when in
            date.timeIntervalSince(when) < 12 * 60 ? EquipmentType(rawValue: key) : nil
        })
    }
}

// MARK: - Coach chat

struct ChatMessage: Codable, Identifiable, Hashable {
    enum Role: String, Codable { case user, assistant }
    var id = UUID()
    var role: Role
    var text: String
    var photoFile: String?
    var at = Date()
}

// MARK: - Health snapshot

struct HealthSnapshot: Codable, Hashable {
    var updatedAt = Date()
    var weightKg: Double?
    var heightCm: Double?
    var age: Int?
    var restingHeartRate: Double?
    var vo2Max: Double?
    var sleepHours: Double?
    var dailySteps: Double?
    var dailyActiveEnergy: Double?
    var workoutsLast7Days: Int?

    var summaryLines: [String] {
        var out: [String] = []
        if let weightKg { out.append(String(format: "Body weight %.1f kg", weightKg)) }
        if let restingHeartRate { out.append(String(format: "Resting heart rate %.0f bpm (7-day average)", restingHeartRate)) }
        if let sleepHours { out.append(String(format: "Sleep %.1f h per night (7-day average)", sleepHours)) }
        if let vo2Max { out.append(String(format: "VO2 max %.1f", vo2Max)) }
        if let dailySteps { out.append(String(format: "%.0f steps per day (7-day average)", dailySteps)) }
        if let dailyActiveEnergy { out.append(String(format: "%.0f kcal active energy per day (7-day average)", dailyActiveEnergy)) }
        if let workoutsLast7Days { out.append("\(workoutsLast7Days) workouts of any kind in the last 7 days") }
        return out
    }
}

// MARK: - Everything that gets saved

struct AppData: Codable {
    var onboarded = false
    var profile = Profile()
    var gyms: [Gym] = []
    var homeGymID: UUID?
    /// The gym you're training in right now; differs from home while travelling.
    var activeGymID: UUID?
    var programs: [Program] = []
    var sessions: [WorkoutSession] = []
    var activeSession: WorkoutSession?
    var chat: [ChatMessage] = []
    var health: HealthSnapshot?
    var healthEnabled = false
    var saveWorkoutsToHealth = true

    init() {}

    /// Missing fields fall back to their defaults, so a file saved by an older version still loads.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        onboarded = try c.decodeIfPresent(Bool.self, forKey: .onboarded) ?? false
        profile = try c.decodeIfPresent(Profile.self, forKey: .profile) ?? Profile()
        gyms = try c.decodeIfPresent([Gym].self, forKey: .gyms) ?? []
        homeGymID = try c.decodeIfPresent(UUID.self, forKey: .homeGymID)
        activeGymID = try c.decodeIfPresent(UUID.self, forKey: .activeGymID)
        programs = try c.decodeIfPresent([Program].self, forKey: .programs) ?? []
        sessions = try c.decodeIfPresent([WorkoutSession].self, forKey: .sessions) ?? []
        activeSession = try c.decodeIfPresent(WorkoutSession.self, forKey: .activeSession)
        chat = try c.decodeIfPresent([ChatMessage].self, forKey: .chat) ?? []
        health = try c.decodeIfPresent(HealthSnapshot.self, forKey: .health)
        healthEnabled = try c.decodeIfPresent(Bool.self, forKey: .healthEnabled) ?? false
        saveWorkoutsToHealth = try c.decodeIfPresent(Bool.self, forKey: .saveWorkoutsToHealth) ?? true
    }
}
