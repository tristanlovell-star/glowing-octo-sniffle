import Foundation

/// Builds a training program from the profile and the equipment a gym actually has.
/// Works entirely on-device; the AI coach can replace its output with a more tailored plan.
enum ProgramBuilder {
    private struct Slot {
        var pattern: MovementPattern
        /// Lower = more important; low-priority slots are dropped for short sessions.
        var priority: Int
    }

    private struct DayTemplate {
        var name: String
        var focus: String
        var slots: [Slot]
    }

    // MARK: Templates

    private static func s(_ pattern: MovementPattern, _ priority: Int) -> Slot { Slot(pattern: pattern, priority: priority) }

    private static let fullBodyA = DayTemplate(name: "Full Body A", focus: "Squat, press, row", slots: [
        s(.squat, 1), s(.horizontalPush, 2), s(.horizontalPull, 3), s(.kneeFlexion, 5),
        s(.lateralRaise, 6), s(.tricepExt, 7), s(.core, 4), s(.calf, 8),
    ])
    private static let fullBodyB = DayTemplate(name: "Full Body B", focus: "Hinge, overhead press, pulldown", slots: [
        s(.hinge, 1), s(.verticalPush, 2), s(.verticalPull, 3), s(.lunge, 4),
        s(.chestFly, 6), s(.bicepCurl, 7), s(.core, 5), s(.rearDelt, 8),
    ])
    private static let fullBodyC = DayTemplate(name: "Full Body C", focus: "Legs, incline press, row", slots: [
        s(.squat, 1), s(.inclinePush, 2), s(.horizontalPull, 3), s(.glute, 4),
        s(.verticalPull, 5), s(.lateralRaise, 7), s(.core, 6), s(.bicepCurl, 8),
    ])
    private static let upperA = DayTemplate(name: "Upper A", focus: "Chest and back", slots: [
        s(.horizontalPush, 1), s(.horizontalPull, 2), s(.verticalPush, 3), s(.verticalPull, 4),
        s(.chestFly, 7), s(.tricepExt, 5), s(.bicepCurl, 6), s(.rearDelt, 8),
    ])
    private static let upperB = DayTemplate(name: "Upper B", focus: "Shoulders and back", slots: [
        s(.verticalPull, 1), s(.inclinePush, 2), s(.horizontalPull, 3), s(.verticalPush, 4),
        s(.lateralRaise, 5), s(.bicepCurl, 6), s(.tricepExt, 7), s(.rearDelt, 8),
    ])
    private static let lowerA = DayTemplate(name: "Lower A", focus: "Quads", slots: [
        s(.squat, 1), s(.hinge, 2), s(.lunge, 4), s(.kneeFlexion, 3),
        s(.calf, 6), s(.core, 5), s(.kneeExtension, 7), s(.hipAbduction, 8),
    ])
    private static let lowerB = DayTemplate(name: "Lower B", focus: "Hamstrings and glutes", slots: [
        s(.hinge, 1), s(.squat, 2), s(.glute, 3), s(.kneeExtension, 4),
        s(.kneeFlexion, 5), s(.core, 6), s(.calf, 7), s(.hipAdduction, 8),
    ])
    private static let push = DayTemplate(name: "Push", focus: "Chest, shoulders, triceps", slots: [
        s(.horizontalPush, 1), s(.verticalPush, 2), s(.inclinePush, 3), s(.lateralRaise, 4),
        s(.tricepExt, 5), s(.chestFly, 6), s(.core, 7),
    ])
    private static let pull = DayTemplate(name: "Pull", focus: "Back and biceps", slots: [
        s(.verticalPull, 1), s(.horizontalPull, 2), s(.rearDelt, 4), s(.bicepCurl, 3),
        s(.hinge, 5), s(.core, 6), s(.bicepCurl, 7),
    ])
    private static let legs = DayTemplate(name: "Legs", focus: "Quads, hamstrings, glutes", slots: [
        s(.squat, 1), s(.hinge, 2), s(.lunge, 3), s(.kneeFlexion, 4),
        s(.kneeExtension, 5), s(.calf, 6), s(.core, 7), s(.glute, 8),
    ])

    private static func templates(daysPerWeek: Int) -> (String, [DayTemplate]) {
        switch daysPerWeek {
        case ...2: return ("Full Body ×2", [fullBodyA, fullBodyB])
        case 3: return ("Full Body ×3", [fullBodyA, fullBodyB, fullBodyC])
        case 4: return ("Upper / Lower", [upperA, lowerA, upperB, lowerB])
        case 5: return ("Upper / Lower + Push Pull Legs", [upperA, lowerA, push, pull, legs])
        default: return ("Push / Pull / Legs ×2", [push, pull, legs, push, pull, legs])
        }
    }

    // MARK: Building

    static func build(profile: Profile, gym: Gym, library: ExerciseLibrary = .shared) -> Program {
        let (splitName, dayTemplates) = templates(daysPerWeek: profile.daysPerWeek)
        let count = exerciseCount(minutes: profile.sessionMinutes)
        let available = gym.available
        let avoid = avoidedExercises(limitations: profile.limitations)
        var usedAcrossProgram: [String: Int] = [:]
        var days: [ProgramDay] = []

        for (index, template) in dayTemplates.enumerated() {
            let keep = Set(template.slots.sorted { $0.priority < $1.priority }.prefix(count).map(\.priority))
            var usedToday: Set<String> = []
            var planned: [PlannedExercise] = []
            for slot in template.slots where keep.contains(slot.priority) {
                guard let exercise = pick(pattern: slot.pattern, available: available, profile: profile,
                                          avoid: avoid, usedToday: usedToday, usedElsewhere: usedAcrossProgram,
                                          library: library) else { continue }
                usedToday.insert(exercise.id)
                usedAcrossProgram[exercise.id, default: 0] += 1
                planned.append(prescription(for: exercise, profile: profile))
            }
            fill(&planned, minimum: min(count, 4), available: available, profile: profile, avoid: avoid, library: library)
            // A repeated template (PPL x2) gets a number so the days are distinguishable.
            let repeats = dayTemplates.filter { $0.name == template.name }.count > 1
            let ordinal = dayTemplates[...index].filter { $0.name == template.name }.count
            let name = repeats ? "\(template.name) \(ordinal)" : template.name
            days.append(ProgramDay(name: name, focus: template.focus, exercises: planned))
        }

        let cardio = warmUpAdvice(gym: gym, goal: profile.goal)
        let rationale = """
        \(splitName) for \(profile.goal.title.lowercased()), \(profile.daysPerWeek) days a week at about \
        \(profile.sessionMinutes) minutes, built from the equipment at \(gym.name). \(cardio)
        """
        return Program(name: splitName, gymID: gym.id, days: days, rationale: rationale, source: .rules)
    }

    /// Re-maps an existing program onto a different gym, keeping its structure and loading scheme.
    /// Used for travel: same plan, different equipment.
    static func adapt(_ program: Program, to gym: Gym, profile: Profile, library: ExerciseLibrary = .shared) -> Program {
        let available = gym.available
        var days: [ProgramDay] = []
        for day in program.days {
            var used: Set<String> = []
            var planned: [PlannedExercise] = []
            for item in day.exercises {
                guard let original = library[item.exerciseID] else { continue }
                if original.equipment(in: available) != nil, !used.contains(original.id) {
                    used.insert(original.id)
                    planned.append(item.fresh())
                    continue
                }
                let options = Coach.alternatives(for: original, available: available, busy: [],
                                                 excluding: used, experience: profile.experience, library: library)
                guard let swap = options.first?.exercise else { continue }
                used.insert(swap.id)
                var copy = item.fresh()
                copy.exerciseID = swap.id
                if swap.loadType != original.loadType || !swap.compound {
                    let base = prescription(for: swap, profile: profile)
                    copy.repMin = base.repMin
                    copy.repMax = base.repMax
                    copy.restSeconds = base.restSeconds
                }
                copy.note = "In place of \(original.name)"
                planned.append(copy)
            }
            fill(&planned, minimum: min(day.exercises.count, 4), available: available, profile: profile,
                 avoid: avoidedExercises(limitations: profile.limitations), library: library)
            days.append(ProgramDay(name: day.name, focus: day.focus, exercises: planned))
        }
        var out = Program(name: "\(program.name) (travel)", gymID: gym.id, days: days, source: .rules)
        out.nextDay = program.nextDay
        out.rationale = "Your usual \(program.name) plan, re-mapped onto what's available at \(gym.name) so you stay on track while you're away."
        return out
    }

    /// Tops a thin session up to a useful minimum. Sparse gyms (a hotel room, no equipment) can't cover
    /// every movement, so this adds whatever productive work the equipment does allow.
    private static func fill(_ planned: inout [PlannedExercise], minimum: Int, available: Set<EquipmentType>,
                             profile: Profile, avoid: Set<String>, library: ExerciseLibrary) {
        let fillers: [MovementPattern] = [.squat, .horizontalPush, .hinge, .lunge, .core, .glute, .verticalPush,
                                          .horizontalPull, .tricepExt, .core, .calf, .lunge, .glute]
        var used = Set(planned.map(\.exerciseID))
        for pattern in fillers where planned.count < minimum {
            guard let exercise = pick(pattern: pattern, available: available, profile: profile, avoid: avoid,
                                      usedToday: used, usedElsewhere: [:], library: library) else { continue }
            used.insert(exercise.id)
            planned.append(prescription(for: exercise, profile: profile))
        }
    }

    // MARK: Choices

    private static func exerciseCount(minutes: Int) -> Int {
        switch minutes {
        case ...30: return 4
        case ...45: return 5
        case ...60: return 6
        case ...75: return 7
        default: return 8
        }
    }

    private static func pick(pattern: MovementPattern, available: Set<EquipmentType>, profile: Profile,
                             avoid: Set<String>, usedToday: Set<String>, usedElsewhere: [String: Int],
                             library: ExerciseLibrary) -> Exercise? {
        let maxDifficulty = profile.experience == .beginner ? 2 : 3
        for candidatePattern in [pattern] + pattern.fallbacks {
            let candidates = library.all.filter {
                $0.pattern == candidatePattern && $0.equipment(in: available) != nil
                    && $0.difficulty <= maxDifficulty && !avoid.contains($0.id) && !usedToday.contains($0.id)
            }
            let best = candidates.min { score($0, profile, usedElsewhere) < score($1, profile, usedElsewhere) }
            if let best { return best }
        }
        return nil
    }

    /// Lower is better.
    private static func score(_ exercise: Exercise, _ profile: Profile, _ usedElsewhere: [String: Int]) -> Double {
        var value = Double(exercise.tier) * 10
        // Rotate exercises between days for variety, but never at the cost of a much worse choice.
        value += Double(usedElsewhere[exercise.id] ?? 0) * 6
        // Weighted work is easier to progress than bodyweight when equipment exists.
        if exercise.loadType == .bodyweight && !exercise.needsNoEquipment { value += 2 }
        if exercise.needsNoEquipment { value += 4 }
        switch profile.experience {
        case .beginner: value += Double(exercise.difficulty - 1) * 5
        case .intermediate: value += abs(Double(exercise.difficulty) - 2) * 2
        case .advanced: value -= Double(exercise.difficulty) * 1.5
        }
        if profile.goal == .getStronger && exercise.compound { value -= Double(exercise.difficulty) * 2 }
        // Stable tie-break so the same inputs always give the same program.
        value += Double(exercise.id.hashValueStable % 100) / 1000
        return value
    }

    static func prescription(for exercise: Exercise, profile: Profile) -> PlannedExercise {
        if exercise.loadType == .timed {
            let hold = profile.experience == .beginner ? (20, 40) : (40, 60)
            return PlannedExercise(exerciseID: exercise.id, sets: 3, repMin: hold.0, repMax: hold.1, restSeconds: 45)
        }
        let main = exercise.compound && exercise.pattern != .core
        let extraSet = profile.experience == .advanced ? 1 : 0
        var sets: Int, repMin: Int, repMax: Int, rest: Int
        switch (profile.goal, main) {
        case (.getStronger, true): (sets, repMin, repMax, rest) = (4, 4, 6, 150)
        case (.getStronger, false): (sets, repMin, repMax, rest) = (3, 8, 10, 90)
        case (.buildMuscle, true): (sets, repMin, repMax, rest) = (3 + extraSet, 8, 12, 105)
        case (.buildMuscle, false): (sets, repMin, repMax, rest) = (3, 10, 15, 60)
        case (.loseFat, true): (sets, repMin, repMax, rest) = (3, 10, 12, 60)
        case (.loseFat, false): (sets, repMin, repMax, rest) = (3, 12, 15, 45)
        case (.generalFitness, true): (sets, repMin, repMax, rest) = (3, 8, 12, 75)
        case (.generalFitness, false): (sets, repMin, repMax, rest) = (2 + extraSet, 12, 15, 60)
        }
        if exercise.pattern == .core || exercise.pattern == .calf { (repMin, repMax) = (12, 15) }
        if profile.experience == .beginner && profile.goal == .getStronger && main {
            // Beginners get stronger fastest with a bit more practice per set.
            (sets, repMin, repMax, rest) = (3, 5, 8, 120)
        }
        return PlannedExercise(exerciseID: exercise.id, sets: sets, repMin: repMin, repMax: repMax, restSeconds: rest)
    }

    /// Very rough keyword screen. The AI coach reads the limitations properly; this just keeps
    /// the offline program away from the most obvious aggravators.
    static func avoidedExercises(limitations: String) -> Set<String> {
        let text = limitations.lowercased()
        var out: Set<String> = []
        if text.contains("shoulder") {
            out.formUnion(["Dips_-_Chest_Version", "Dips_-_Triceps_Version", "Bench_Dips", "Standing_Military_Press",
                           "Barbell_Bench_Press_-_Medium_Grip", "Pullups"])
        }
        if text.contains("back") || text.contains("disc") || text.contains("sciatic") {
            out.formUnion(["Barbell_Deadlift", "Bent_Over_Barbell_Row", "Band_Good_Morning", "Barbell_Squat",
                           "Front_Barbell_Squat", "Romanian_Deadlift", "Smith_Machine_Bent_Over_Row",
                           "Bent_Over_Two-Dumbbell_Row", "Standing_Military_Press"])
        }
        if text.contains("knee") {
            out.formUnion(["Split_Squat_with_Dumbbells", "Barbell_Lunge", "Hack_Squat", "Leg_Extensions",
                           "Bodyweight_Walking_Lunge", "Dumbbell_Lunges", "Front_Barbell_Squat"])
        }
        if text.contains("wrist") || text.contains("elbow") {
            out.formUnion(["EZ-Bar_Skullcrusher", "Barbell_Curl", "Pushups", "Bench_Dips"])
        }
        return out
    }

    static func warmUpAdvice(gym: Gym, goal: Goal) -> String {
        let cardio = gym.equipment.map(\.type).first { $0.isCardio }
        let machine = cardio?.displayName.lowercased() ?? "brisk walking or skipping on the spot"
        var text = "Warm up with 5 minutes on the \(machine), then one or two light sets of your first exercise."
        if cardio == nil { text = "Warm up with 5 minutes of \(machine), then one or two light sets of your first exercise." }
        if goal == .loseFat {
            text += " Finish with 10–15 minutes of steady cardio if you have time."
        }
        return text
    }
}

extension PlannedExercise {
    /// A copy with a new identity, for building a new program from an old one.
    func fresh() -> PlannedExercise {
        var copy = self
        copy.id = UUID()
        return copy
    }
}

extension String {
    /// A hash that doesn't change between launches (Swift's hashValue is randomly seeded).
    var hashValueStable: UInt {
        var hash: UInt = 5381
        for byte in utf8 { hash = (hash &* 33) &+ UInt(byte) }
        return hash
    }
}
