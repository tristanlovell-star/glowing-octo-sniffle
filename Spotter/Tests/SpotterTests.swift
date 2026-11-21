import XCTest
@testable import Spotter

/// Checks the on-device brain: the library, the program builder, machine-busy alternatives,
/// re-ordering, progression targets and travel re-mapping.
final class SpotterTests: XCTestCase {
    private let library = ExerciseLibrary.shared

    private func makeGym(_ preset: GymPreset, kind: Gym.Kind = .home) -> Gym {
        var gym = Gym(name: preset.title, kind: kind)
        for type in preset.equipment { gym.add(type) }
        return gym
    }

    private func log(_ program: Program) {
        print("SPOTTER| \(program.name)")
        for day in program.days {
            let items = day.exercises.map { "\(library.name($0.exerciseID)) \($0.sets)x\($0.repMin)-\($0.repMax)" }
            print("SPOTTER|   \(day.name): " + items.joined(separator: "; "))
        }
    }

    func testLibraryLoadsWithPhotos() throws {
        XCTAssertEqual(library.all.count, 139)
        for exercise in library.all {
            XCTAssertEqual(exercise.images.count, 2, exercise.id)
            for image in exercise.images {
                XCTAssertNotNil(Bundle.main.url(forResource: image, withExtension: "jpg"), "missing photo \(image)")
            }
            XCTAssertFalse(exercise.instructions.isEmpty, exercise.id)
        }
        // Every strength equipment type has at least one exercise and a guide.
        for type in EquipmentType.allCases {
            XCTAssertFalse(type.guide.setup.isEmpty, type.rawValue)
            if !type.isCardio {
                XCTAssertFalse(library.exercises(using: type).isEmpty, "no exercises for \(type.rawValue)")
            }
        }
    }

    func testProgramsForEveryGymAndSchedule() {
        for preset in GymPreset.allCases {
            let gym = makeGym(preset)
            for experience in Experience.allCases {
                for goal in Goal.allCases {
                    for days in 2...6 {
                        var profile = Profile()
                        profile.experience = experience
                        profile.goal = goal
                        profile.daysPerWeek = days
                        profile.sessionMinutes = 60
                        let program = ProgramBuilder.build(profile: profile, gym: gym, library: library)
                        if goal == .buildMuscle && experience == .intermediate { log(program) }
                        XCTAssertEqual(program.days.count, max(days, 2))
                        XCTAssertEqual(Set(program.days.map(\.name)).count, program.days.count, "day names must be unique")
                        for day in program.days {
                            let ids = day.exercises.map(\.exerciseID)
                            XCTAssertGreaterThanOrEqual(ids.count, 4, "\(preset) \(days)d \(day.name)")
                            XCTAssertEqual(Set(ids).count, ids.count, "duplicate exercise in \(day.name)")
                            for id in ids {
                                let exercise = try! XCTUnwrap(library[id])
                                XCTAssertNotNil(exercise.equipment(in: gym.available), "\(id) not possible in \(preset)")
                                if experience == .beginner { XCTAssertLessThanOrEqual(exercise.difficulty, 2) }
                            }
                        }
                    }
                }
            }
        }
    }

    func testSessionLengthChangesExerciseCount() {
        var profile = Profile()
        profile.sessionMinutes = 30
        let short = ProgramBuilder.build(profile: profile, gym: makeGym(.commercial), library: library)
        profile.sessionMinutes = 90
        let long = ProgramBuilder.build(profile: profile, gym: makeGym(.commercial), library: library)
        XCTAssertEqual(short.days[0].exercises.count, 4)
        XCTAssertEqual(long.days[0].exercises.count, 8)
    }

    func testLimitationsAreRespected() {
        var profile = Profile()
        profile.experience = .advanced
        profile.goal = .getStronger
        profile.limitations = "Dodgy lower back"
        let program = ProgramBuilder.build(profile: profile, gym: makeGym(.commercial), library: library)
        let ids = Set(program.days.flatMap(\.exercises).map(\.exerciseID))
        XCTAssertFalse(ids.contains("Barbell_Deadlift"))
        XCTAssertFalse(ids.contains("Barbell_Squat"))
    }

    func testBusyMachineGivesAlternativesThatAvoidIt() throws {
        let gym = makeGym(.commercial)
        for exercise in library.available(in: gym.available) {
            let busy = Set(Coach.likelyBusy(for: exercise, available: gym.available))
            let options = Coach.alternatives(for: exercise, available: gym.available, busy: busy, excluding: [],
                                             experience: .intermediate, library: library)
            if exercise.pattern != .calf && exercise.pattern != .core {
                XCTAssertFalse(options.isEmpty, "no alternative for \(exercise.name)")
            }
            for option in options {
                XCTAssertNotEqual(option.exercise.id, exercise.id)
                XCTAssertTrue(busy.isDisjoint(with: option.equipment), "\(option.exercise.name) uses busy gear")
            }
        }
        let pulldown = try XCTUnwrap(library["Wide-Grip_Lat_Pulldown"])
        let options = Coach.alternatives(for: pulldown, available: gym.available, busy: [.latPulldown], excluding: [],
                                         experience: .beginner, library: library)
        print("SPOTTER| Lat pulldown busy -> " + options.map { "\($0.exercise.name) [\($0.reason)]" }.joined(separator: " | "))
        XCTAssertEqual(options.first?.exercise.pattern, .verticalPull)
    }

    func testReorderingFindsAnExerciseWithFreeEquipment() throws {
        let gym = makeGym(.commercial)
        let ids = ["Leg_Press", "Calf_Press_On_The_Leg_Press_Machine", "Seated_Leg_Curl", "Plank"]
        var session = WorkoutSession(dayName: "Test", gymID: gym.id, gymName: gym.name, exercises: ids.map {
            SessionExercise(exerciseID: $0, targetSets: 3, repMin: 8, repMax: 12, restSeconds: 60)
        })
        session.busy[EquipmentType.legPress.rawValue] = Date()
        // The leg press calf raise also needs the busy leg press, so the leg curl is next.
        XCTAssertEqual(Coach.nextFreeExercise(in: session, after: 0, available: gym.available, library: library), 2)
        // Reports expire.
        session.busy[EquipmentType.legPress.rawValue] = Date().addingTimeInterval(-3600)
        XCTAssertEqual(Coach.nextFreeExercise(in: session, after: 0, available: gym.available, library: library), 1)
    }

    func testProgressionTargets() throws {
        let exercise = try XCTUnwrap(library["Machine_Bench_Press"])
        let item = SessionExercise(exerciseID: exercise.id, targetSets: 3, repMin: 8, repMax: 12, restSeconds: 90)

        func session(_ sets: [(Double, Int, Effort)], daysAgo: Double) -> WorkoutSession {
            var done = item
            done.sets = sets.map { LoggedSet(weightKg: $0.0, reps: $0.1, effort: $0.2) }
            var session = WorkoutSession(dayName: "A", gymID: UUID(), gymName: "Gym", exercises: [done])
            session.startedAt = Date().addingTimeInterval(-daysAgo * 86400)
            session.endedAt = session.startedAt.addingTimeInterval(3000)
            return session
        }

        let first = Coach.target(for: item, exercise: exercise, sessions: [])
        XCTAssertNil(first.weightKg)

        let topped = Coach.target(for: item, exercise: exercise,
                                  sessions: [session([(40, 12, .moderate), (40, 12, .moderate), (40, 12, .hard)], daysAgo: 2)])
        XCTAssertEqual(topped.weightKg, 42.5)

        let cruising = Coach.target(for: item, exercise: exercise,
                                    sessions: [session([(40, 12, .easy), (40, 12, .easy), (40, 12, .easy)], daysAgo: 2)])
        XCTAssertEqual(cruising.weightKg, 45)

        let middle = Coach.target(for: item, exercise: exercise,
                                  sessions: [session([(40, 10, .hard), (40, 9, .hard), (40, 8, .maxed)], daysAgo: 2)])
        XCTAssertEqual(middle.weightKg, 40)
        XCTAssertEqual(middle.repGoal, 11)

        let tooHeavy = Coach.target(for: item, exercise: exercise,
                                    sessions: [session([(50, 6, .maxed), (50, 5, .maxed), (50, 4, .maxed)], daysAgo: 2)])
        XCTAssertEqual(tooHeavy.weightKg, 45)
        for target in [first, topped, cruising, middle, tooHeavy] { print("SPOTTER| target: \(target.headline) — \(target.detail)") }
    }

    func testTravelProgramMirrorsHomeProgram() {
        var profile = Profile()
        profile.experience = .intermediate
        profile.goal = .buildMuscle
        profile.daysPerWeek = 4
        profile.sessionMinutes = 60
        var home = ProgramBuilder.build(profile: profile, gym: makeGym(.commercial), library: library)
        home.nextDay = 2
        for preset in [GymPreset.hotel, .bodyweight] {
            let hotel = makeGym(preset, kind: .travel)
            let travel = ProgramBuilder.adapt(home, to: hotel, profile: profile, library: library)
            log(travel)
            XCTAssertEqual(travel.days.map(\.name), home.days.map(\.name))
            XCTAssertEqual(travel.nextDay, 2)
            for day in travel.days {
                XCTAssertGreaterThanOrEqual(day.exercises.count, 4, "\(preset) \(day.name)")
                XCTAssertEqual(Set(day.exercises.map(\.exerciseID)).count, day.exercises.count)
                for item in day.exercises {
                    XCTAssertNotNil(library[item.exerciseID]?.equipment(in: hotel.available))
                }
            }
        }
    }

    func testSavedDataRoundTrips() throws {
        var data = AppData()
        let gym = makeGym(.commercial)
        data.gyms = [gym]
        data.homeGymID = gym.id
        data.programs = [ProgramBuilder.build(profile: data.profile, gym: gym, library: library)]
        data.sessions = [WorkoutSession(dayName: "A", gymID: gym.id, gymName: gym.name, exercises: [])]
        data.sessions[0].busy["legPress"] = Date()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let copy = try decoder.decode(AppData.self, from: encoder.encode(data))
        XCTAssertEqual(copy.programs.first?.days.count, data.programs.first?.days.count)
        XCTAssertEqual(copy.gyms.first?.available, gym.available)
        // Older saves without newer fields must still load.
        let minimal = try decoder.decode(AppData.self, from: Data("{}".utf8))
        XCTAssertFalse(minimal.onboarded)
    }

    func testInsightsAfterTraining() {
        let data = DemoData.make(library: library)
        let insights = Coach.insights(data: data, library: library)
        for insight in insights { print("SPOTTER| insight: \(insight.title) — \(insight.detail)") }
        XCTAssertFalse(insights.isEmpty)
    }
}
