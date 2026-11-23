import Foundation

/// On-device coaching logic: what to do when equipment is busy, how to progress, and what to flag.
enum Coach {
    // MARK: - Machine busy

    struct Alternative: Identifiable, Hashable {
        var exercise: Exercise
        var equipment: [EquipmentType]
        var reason: String
        var id: String { exercise.id }
    }

    /// Exercises that train the same thing as `original` using equipment that's free right now.
    static func alternatives(for original: Exercise, available: Set<EquipmentType>, busy: Set<EquipmentType>,
                             excluding: Set<String>, experience: Experience,
                             library: ExerciseLibrary = .shared, limit: Int = 5) -> [Alternative] {
        let maxDifficulty = experience == .beginner ? 2 : 3
        var out: [Alternative] = []
        var seen: Set<String> = [original.id]
        for (rank, pattern) in ([original.pattern] + original.pattern.fallbacks).enumerated() {
            let candidates = library.all.compactMap { exercise -> (Exercise, [EquipmentType], Double)? in
                guard exercise.pattern == pattern, !seen.contains(exercise.id), !excluding.contains(exercise.id),
                      exercise.difficulty <= maxDifficulty,
                      let gear = exercise.equipment(in: available, excluding: busy) else { return nil }
                var score = Double(exercise.tier) * 3
                let sharedMuscles = Set(exercise.primaryMuscles).intersection(original.primaryMuscles).count
                score -= Double(sharedMuscles) * 4
                if exercise.compound != original.compound { score += 3 }
                if exercise.loadType != original.loadType { score += 2 }
                score += abs(Double(exercise.difficulty - original.difficulty))
                if gear.isEmpty { score += 1.5 }
                return (exercise, gear, score)
            }
            for (exercise, gear, _) in candidates.sorted(by: { $0.2 < $1.2 }) {
                seen.insert(exercise.id)
                let with = gear.isEmpty ? "no equipment needed" : "uses the " + gear.map { $0.displayName.lowercased() }.joined(separator: " + ")
                let reason = rank == 0
                    ? "Same movement — \(with)"
                    : "Similar muscles (\(exercise.muscleSummary.lowercased())) — \(with)"
                out.append(Alternative(exercise: exercise, equipment: gear, reason: reason))
                if out.count >= limit { return out }
            }
        }
        return out
    }

    /// When you'd rather wait for the machine: the next unfinished exercise whose equipment is free.
    static func nextFreeExercise(in session: WorkoutSession, after index: Int, available: Set<EquipmentType>,
                                 library: ExerciseLibrary = .shared) -> Int? {
        let busy = session.busyNow()
        let order = Array(session.exercises.indices.dropFirst(index + 1)) + Array(session.exercises.indices.prefix(index))
        return order.first { i in
            let item = session.exercises[i]
            guard !item.isDone, let exercise = library[item.exerciseID] else { return false }
            return exercise.equipment(in: available, excluding: busy) != nil
        }
    }

    /// Which of an exercise's equipment is most likely the thing that's taken.
    static func likelyBusy(for exercise: Exercise, available: Set<EquipmentType>) -> [EquipmentType] {
        let gear = exercise.equipment(in: available) ?? exercise.requiresAny.first ?? []
        let scarce = gear.filter { !$0.isPlentiful }
        return scarce.isEmpty ? gear : scarce
    }

    // MARK: - Progression

    struct Target: Hashable {
        var weightKg: Double?
        var repGoal: Int
        var headline: String
        var detail: String
    }

    /// The most recent completed sets for an exercise, newest session first.
    static func history(for exerciseID: String, in sessions: [WorkoutSession]) -> [(date: Date, sets: [LoggedSet])] {
        sessions
            .filter { $0.endedAt != nil }
            .sorted { $0.startedAt > $1.startedAt }
            .compactMap { session -> (date: Date, sets: [LoggedSet])? in
                let sets = session.exercises.filter { $0.exerciseID == exerciseID }.flatMap(\.sets)
                return sets.isEmpty ? nil : (date: session.startedAt, sets: sets)
            }
    }

    static func target(for item: SessionExercise, exercise: Exercise, sessions: [WorkoutSession]) -> Target {
        let past = history(for: exercise.id, in: sessions)
        let unit = exercise.loadType == .timed ? "sec" : "reps"
        guard let last = past.first else {
            switch exercise.loadType {
            case .weighted:
                return Target(weightKg: nil, repGoal: item.repMax,
                              headline: "First time — find your weight",
                              detail: "Start light. Pick a weight you could lift about \(item.repMax + 3) times, and stop at \(item.repMax). Log how it felt and I'll set the next one.")
            case .bodyweight:
                return Target(weightKg: 0, repGoal: item.repMin,
                              headline: "Aim for \(item.repMin)–\(item.repMax) reps",
                              detail: "Stop each set with a rep or two left in the tank.")
            case .timed:
                return Target(weightKg: 0, repGoal: item.repMin,
                              headline: "Hold for \(item.repMin)–\(item.repMax) sec",
                              detail: "Stop when your form starts to slip.")
            }
        }

        let sets = last.sets
        let topWeight = sets.map(\.weightKg).max() ?? 0
        let working = sets.filter { $0.weightKg == topWeight }
        let hitTop = working.count >= min(item.targetSets, 2) && working.allSatisfy { $0.reps >= item.repMax }
        let missedBottom = working.filter { $0.reps < item.repMin }.count
        let hardest = working.map(\.effort.rawValue).max() ?? 7
        let allEasy = working.allSatisfy { $0.effort == .easy }
        let lastSummary = working.map { "\($0.reps)" }.joined(separator: ", ")

        if exercise.loadType != .weighted || topWeight == 0 {
            let best = working.map(\.reps).max() ?? item.repMin
            if hitTop {
                return Target(weightKg: 0, repGoal: best + (exercise.loadType == .timed ? 5 : 1),
                              headline: "Beat \(best) \(unit)",
                              detail: "You hit the top of the range last time (\(lastSummary)). Add a little, or slow the lowering phase to make it harder.")
            }
            return Target(weightKg: 0, repGoal: min(best + (exercise.loadType == .timed ? 5 : 1), item.repMax),
                          headline: "Aim for \(min(best + 1, item.repMax)) \(unit)",
                          detail: "Last time: \(lastSummary). Add one more than last time on at least one set.")
        }

        let step = increment(for: exercise, at: topWeight)
        let weightText = format(topWeight)
        if hitTop && hardest <= Effort.hard.rawValue {
            let jump = allEasy ? step * 2 : step
            let next = topWeight + jump
            return Target(weightKg: next, repGoal: item.repMin,
                          headline: "Go up to \(format(next)) kg",
                          detail: "Last time you got \(lastSummary) at \(weightText) kg — top of the range. Add \(format(jump)) kg and aim for \(item.repMin)+ reps.")
        }
        if missedBottom >= 2 || (missedBottom >= 1 && hardest == Effort.maxed.rawValue && working.count <= 2) {
            let next = max(roundTo(topWeight * 0.9, step: step), step)
            return Target(weightKg: next, repGoal: item.repMin + 1,
                          headline: "Drop to \(format(next)) kg",
                          detail: "Last time (\(lastSummary) at \(weightText) kg) fell short of \(item.repMin) reps. Take about 10% off and own the full range.")
        }
        let stalled = past.prefix(3).count == 3 && past.prefix(3).allSatisfy { entry in
            (entry.sets.map(\.weightKg).max() ?? 0) == topWeight
                && (entry.sets.map(\.reps).max() ?? 0) <= (working.map(\.reps).max() ?? 0)
        }
        if stalled {
            return Target(weightKg: topWeight, repGoal: item.repMax,
                          headline: "Stay at \(weightText) kg — break the plateau",
                          detail: "Three sessions at the same numbers. Add one rep to your first set today, or rest 30 seconds longer between sets.")
        }
        let best = working.map(\.reps).max() ?? item.repMin
        return Target(weightKg: topWeight, repGoal: min(best + 1, item.repMax),
                      headline: "Stay at \(weightText) kg, add a rep",
                      detail: "Last time: \(lastSummary). When every set reaches \(item.repMax), the weight goes up.")
    }

    static func increment(for exercise: Exercise, at weight: Double) -> Double {
        let usesDumbbells = exercise.requiresAny.first?.contains(.dumbbells) ?? false
        if usesDumbbells || exercise.requiresAny.first?.contains(.kettlebells) ?? false {
            return weight < 10 ? 1 : 2.5
        }
        if exercise.compound && exercise.pattern.isLowerBody { return 5 }
        if !exercise.compound { return weight < 20 ? 1.25 : 2.5 }
        return 2.5
    }

    static func roundTo(_ value: Double, step: Double) -> Double {
        guard step > 0 else { return value }
        return (value / step).rounded() * step
    }

    static func format(_ weight: Double) -> String {
        if weight == weight.rounded() { return String(format: "%.0f", weight) }
        if weight * 2 == (weight * 2).rounded() { return String(format: "%.1f", weight) }
        return String(format: "%.2f", weight)
    }

    /// Epley estimate of a one-rep max, the standard way to compare sets at different weights.
    static func estimatedMax(_ set: LoggedSet) -> Double {
        set.reps <= 1 ? set.weightKg : set.weightKg * (1 + Double(set.reps) / 30)
    }

    // MARK: - Insights

    struct Insight: Identifiable, Hashable {
        enum Tone { case good, info, warning }
        var id = UUID()
        var tone: Tone
        var title: String
        var detail: String
    }

    static func insights(data: AppData, library: ExerciseLibrary = .shared, now: Date = Date()) -> [Insight] {
        var out: [Insight] = []
        let done = data.sessions.filter { $0.endedAt != nil }.sorted { $0.startedAt > $1.startedAt }
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let thisWeek = done.filter { $0.startedAt >= weekAgo }
        let target = data.profile.daysPerWeek

        if done.isEmpty {
            out.append(Insight(tone: .info, title: "Your first session sets the baseline",
                               detail: "Log the weight, reps and how hard each set felt. From the second session on I'll tell you exactly what to lift."))
        } else {
            if thisWeek.count >= target {
                out.append(Insight(tone: .good, title: "\(thisWeek.count) of \(target) sessions in the last 7 days",
                                   detail: "You're on plan. Consistency is what drives results — keep the streak going."))
            } else if let latest = done.first {
                let gap = calendar.dateComponents([.day], from: latest.startedAt, to: now).day ?? 0
                if gap >= 5 {
                    out.append(Insight(tone: .warning, title: "\(gap) days since your last session",
                                       detail: "Ease back in: use last session's weights and stop a rep earlier than usual today."))
                } else {
                    out.append(Insight(tone: .info, title: "\(thisWeek.count) of \(target) sessions in the last 7 days",
                                       detail: "\(target - thisWeek.count) more to hit your weekly plan."))
                }
            }
        }

        // Personal bests in the most recent session.
        if let latest = done.first {
            let earlier = Array(done.dropFirst())
            var bests: [String] = []
            for item in latest.exercises {
                guard let exercise = library[item.exerciseID], exercise.loadType == .weighted,
                      let top = item.sets.map(estimatedMax).max(), top > 0 else { continue }
                let previous = earlier.flatMap(\.exercises).filter { $0.exerciseID == item.exerciseID }
                    .flatMap(\.sets).map(estimatedMax).max()
                if let previous, top > previous * 1.001 { bests.append(exercise.name) }
            }
            if !bests.isEmpty {
                out.append(Insight(tone: .good, title: "New best on \(bests.prefix(3).joined(separator: ", "))",
                                   detail: "Your last session beat every previous one on \(bests.count == 1 ? "this lift" : "these lifts")."))
            }
        }

        // Lifts that have stopped moving.
        var stalled: [String] = []
        for id in Set(done.prefix(6).flatMap(\.exercises).map(\.exerciseID)) {
            guard let exercise = library[id], exercise.loadType == .weighted else { continue }
            let past = history(for: id, in: done).prefix(4).map { $0.sets.map(estimatedMax).max() ?? 0 }
            if past.count == 4, let newest = past.first, let oldest = past.last, newest <= oldest {
                stalled.append(exercise.name)
            }
        }
        if !stalled.isEmpty {
            out.append(Insight(tone: .warning, title: "Plateau: \(stalled.sorted().prefix(3).joined(separator: ", "))",
                               detail: "No progress over the last four sessions. Try a small deload (10% lighter for a week) or swap in a variation for a month."))
        }

        // Effort trend.
        let recentSets = done.prefix(3).flatMap(\.exercises).flatMap(\.sets)
        if recentSets.count >= 12 {
            let maxed = Double(recentSets.filter { $0.effort == .maxed }.count) / Double(recentSets.count)
            let easy = Double(recentSets.filter { $0.effort == .easy }.count) / Double(recentSets.count)
            if maxed > 0.4 {
                out.append(Insight(tone: .warning, title: "You're going to failure a lot",
                                   detail: "Over 40% of recent sets were all-out. Leaving 1–2 reps in reserve on most sets recovers better and builds just as much."))
            } else if easy > 0.5 {
                out.append(Insight(tone: .info, title: "Room to push harder",
                                   detail: "More than half your recent sets felt easy. Take the suggested weight jumps — the last few reps should be a real effort."))
            }
        }

        // Recovery signals from Apple Health.
        if let health = data.health {
            if let sleep = health.sleepHours, sleep < 6.5 {
                out.append(Insight(tone: .warning, title: String(format: "Averaging %.1f h sleep", sleep),
                                   detail: "Short sleep blunts strength and recovery. Keep today's weights where they are rather than chasing increases."))
            }
            if let steps = health.dailySteps, data.profile.goal == .loseFat, steps < 7000 {
                out.append(Insight(tone: .info, title: String(format: "%.0f steps a day", steps),
                                   detail: "For fat loss, daily movement matters as much as gym time. Aim for 8–10k steps."))
            }
        }

        // Still on an unchecked preset list: programs and swaps are only as good as the equipment list.
        if let home = data.gyms.first(where: { $0.id == data.homeGymID }), !home.equipment.isEmpty,
           home.equipment.allSatisfy({ $0.photoFile == nil && $0.label.isEmpty }) {
            out.append(Insight(tone: .info, title: "Check your equipment list on a quiet visit",
                               detail: "\(home.name) is still on the standard list. Open Equipment › Edit gym to untick what isn't there and add what is — no photos needed. If you do take photos, close-ups of a machine with nobody on it work best."))
        }

        if let travel = data.gyms.first(where: { $0.id == data.activeGymID }), travel.kind == .travel {
            out.append(Insight(tone: .info, title: "Travel mode: \(travel.name)",
                               detail: "Weights on substituted exercises won't match your home gym. Go by effort: finish each set with 1–2 reps left."))
        }
        return out
    }
}
