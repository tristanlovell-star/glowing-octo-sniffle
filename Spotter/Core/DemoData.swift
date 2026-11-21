import Foundation

/// Sample data for previews, tests and screenshots: a set-up user with a few weeks of training.
/// Only used when the app is launched with the `-demo` argument; never touches saved data.
enum DemoData {
    static func make(library: ExerciseLibrary = .shared, now: Date = Date()) -> AppData {
        var data = AppData()
        data.onboarded = true
        data.profile = Profile(name: "Sam", age: 38, weightKg: 82.5, heightCm: 181, experience: .intermediate,
                               goal: .buildMuscle, daysPerWeek: 3, sessionMinutes: 60)

        var gym = Gym(name: "Snap Fitness New Farm")
        for type in GymPreset.commercial.equipment { gym.add(type) }
        data.gyms = [gym]
        data.homeGymID = gym.id
        data.activeGymID = gym.id

        var program = ProgramBuilder.build(profile: data.profile, gym: gym, library: library)

        // Nine sessions over three weeks, each a little better than the last.
        let efforts: [Effort] = [.moderate, .moderate, .hard]
        for index in 0..<9 {
            let day = program.days[index % program.days.count]
            let start = now.addingTimeInterval(-Double(9 - index) * 2.3 * 86400)
            let cycle = index / program.days.count
            var items: [SessionExercise] = []
            for planned in day.exercises {
                guard let exercise = library[planned.exerciseID] else { continue }
                var item = SessionExercise(exerciseID: planned.exerciseID, targetSets: planned.sets, repMin: planned.repMin,
                                           repMax: planned.repMax, restSeconds: planned.restSeconds)
                let base: Double = exercise.loadType == .weighted
                    ? (exercise.compound ? (exercise.pattern.isLowerBody ? 60 : 35) : 12) : 0
                let step = exercise.loadType == .weighted ? Coach.increment(for: exercise, at: base) : 0
                for set in 0..<planned.sets {
                    let reps = min(planned.repMin + cycle + (set == 0 ? 2 : 0), planned.repMax)
                    item.sets.append(LoggedSet(weightKg: base + step * Double(cycle), reps: reps,
                                               effort: efforts[min(set, efforts.count - 1)],
                                               at: start.addingTimeInterval(Double(set) * 150)))
                }
                items.append(item)
            }
            var session = WorkoutSession(programID: program.id, dayName: day.name, gymID: gym.id, gymName: gym.name,
                                         exercises: items)
            session.startedAt = start
            session.endedAt = start.addingTimeInterval(54 * 60)
            session.overallEffort = 7
            session.averageHeartRate = 118
            session.savedToHealth = true
            data.sessions.append(session)
        }
        program.nextDay = 9 % program.days.count
        data.programs = [program]

        data.healthEnabled = true
        data.health = HealthSnapshot(updatedAt: now, weightKg: 82.5, heightCm: 181, age: 38, restingHeartRate: 58,
                                     vo2Max: 42.1, sleepHours: 7.2, dailySteps: 8400, dailyActiveEnergy: 520,
                                     workoutsLast7Days: 4)
        return data
    }
}
