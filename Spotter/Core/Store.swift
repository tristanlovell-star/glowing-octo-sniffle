import Foundation
import SwiftUI
import UIKit

/// The single source of truth. Everything is saved to one JSON file in Application Support;
/// photos are JPEG files alongside it.
@MainActor
final class AppStore: ObservableObject {
    @Published var data: AppData {
        didSet { scheduleSave() }
    }

    /// Which tab is showing (0 Today, 1 Program, 2 Progress, 3 Coach, 4 Equipment). Not saved.
    @Published var selectedTab = 0
    /// A question queued up for the coach from elsewhere in the app. Not saved.
    @Published var coachDraft: CoachDraft?

    struct CoachDraft: Equatable {
        var text: String
        var photoFile: String?
    }

    let library = ExerciseLibrary.shared
    private var saveTask: Task<Void, Never>?
    /// False in demo mode, so sample data never overwrites the real file.
    private let persists: Bool
    /// The screen requested with `-demoScreen` when launched in demo mode.
    let demoScreen: String?

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-demo") {
            persists = false
            let screen = arguments.firstIndex(of: "-demoScreen").flatMap { index in
                arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
            }
            demoScreen = screen
            var demo = DemoData.make()
            if screen == "onboarding" { demo = AppData() }
            data = demo
            applyDemoScreen(screen)
            return
        }
        persists = true
        demoScreen = nil
        if let raw = try? Data(contentsOf: Self.fileURL) {
            if let decoded = try? Self.decoder.decode(AppData.self, from: raw) {
                data = decoded
            } else {
                // Never silently throw away a file we can't read: keep it beside the new one.
                let stamp = Int(Date().timeIntervalSince1970)
                try? raw.write(to: Self.folder.appendingPathComponent("spotter-unreadable-\(stamp).json"))
                data = AppData()
            }
        } else {
            data = AppData()
        }
    }

    // MARK: Persistence

    nonisolated private static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Spotter", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    nonisolated private static var fileURL: URL { folder.appendingPathComponent("spotter.json") }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let self else { return }
            self.saveNow()
        }
    }

    func saveNow() {
        guard persists else { return }
        guard let raw = try? Self.encoder.encode(data) else { return }
        try? raw.write(to: Self.fileURL, options: .atomic)
    }

    private func applyDemoScreen(_ screen: String?) {
        let tabs = ["today": 0, "program": 1, "progress": 2, "coach": 3, "equipment": 4]
        if let screen, let tab = tabs[screen] { selectedTab = tab }
        if screen == "travel" {
            var hotel = Gym(name: "Hotel gym, Sydney", kind: .travel)
            for type in GymPreset.hotel.equipment { hotel.add(type) }
            upsert(hotel)
            data.activeGymID = hotel.id
            buildProgram(for: hotel)
            selectedTab = 1
        }
        if ["workout", "busy", "detail"].contains(screen ?? ""), let program = activeProgram, let day = program.upcomingDay {
            startWorkout(day: day, program: program)
            if let first = data.activeSession?.exercises.first {
                data.activeSession?.exercises[0].sets = [
                    LoggedSet(weightKg: 40, reps: first.repMax, effort: .moderate),
                ]
            }
        }
    }

    // MARK: Photos

    nonisolated static func photoURL(_ file: String) -> URL { folder.appendingPathComponent(file) }

    /// Saves a downscaled JPEG and returns its file name.
    nonisolated static func savePhoto(_ jpeg: Data) -> String {
        let name = UUID().uuidString + ".jpg"
        try? jpeg.write(to: photoURL(name), options: .atomic)
        return name
    }

    nonisolated static func loadPhoto(_ file: String?) -> UIImage? {
        guard let file, let raw = try? Data(contentsOf: photoURL(file)) else { return nil }
        return UIImage(data: raw)
    }

    nonisolated static func photoData(_ file: String?) -> Data? {
        guard let file else { return nil }
        return try? Data(contentsOf: photoURL(file))
    }

    // MARK: Gyms

    var activeGym: Gym? {
        data.gyms.first { $0.id == data.activeGymID } ?? homeGym
    }

    var homeGym: Gym? {
        data.gyms.first { $0.id == data.homeGymID }
    }

    var isTravelling: Bool { activeGym?.kind == .travel }

    func upsert(_ gym: Gym) {
        if let index = data.gyms.firstIndex(where: { $0.id == gym.id }) {
            data.gyms[index] = gym
        } else {
            data.gyms.append(gym)
        }
    }

    func endTravel() {
        data.activeGymID = data.homeGymID
    }

    func askCoach(_ text: String, photoFile: String? = nil) {
        coachDraft = CoachDraft(text: text, photoFile: photoFile)
        selectedTab = 3
    }

    func resetEverything() {
        Keychain.apiKey = nil
        data = AppData()
    }

    // MARK: Programs

    /// The program for the gym you're in right now.
    var activeProgram: Program? {
        guard let gym = activeGym else { return nil }
        return data.programs.last { $0.gymID == gym.id }
    }

    var homeProgram: Program? {
        guard let id = data.homeGymID else { return nil }
        return data.programs.last { $0.gymID == id }
    }

    func setProgram(_ program: Program) {
        data.programs.removeAll { $0.gymID == program.gymID }
        data.programs.append(program)
    }

    func updateProgram(_ id: UUID, _ change: (inout Program) -> Void) {
        guard let index = data.programs.firstIndex(where: { $0.id == id }) else { return }
        change(&data.programs[index])
    }

    /// Builds the on-device program for a gym and makes it current.
    @discardableResult
    func buildProgram(for gym: Gym) -> Program {
        let program: Program
        if gym.kind == .travel, let home = homeProgram {
            program = ProgramBuilder.adapt(home, to: gym, profile: data.profile, library: library)
        } else {
            program = ProgramBuilder.build(profile: data.profile, gym: gym, library: library)
        }
        setProgram(program)
        return program
    }

    // MARK: Workouts

    func startWorkout(day: ProgramDay, program: Program) {
        guard let gym = activeGym else { return }
        let items = day.exercises.map {
            SessionExercise(exerciseID: $0.exerciseID, targetSets: $0.sets, repMin: $0.repMin, repMax: $0.repMax,
                            restSeconds: $0.restSeconds, note: $0.note)
        }
        data.activeSession = WorkoutSession(programID: program.id, dayName: day.name, gymID: gym.id,
                                            gymName: gym.name, exercises: items)
    }

    func finishWorkout(overallEffort: Int, notes: String) -> WorkoutSession? {
        guard var session = data.activeSession else { return nil }
        session.endedAt = Date()
        session.overallEffort = overallEffort
        session.notes = notes
        data.sessions.append(session)
        data.activeSession = nil
        if let programID = session.programID {
            updateProgram(programID) { program in
                if !program.days.isEmpty { program.nextDay = (program.nextDay + 1) % program.days.count }
            }
            // Keep the home program in step while travelling, so you resume where you left off.
            if isTravelling, let home = homeProgram, home.id != programID {
                updateProgram(home.id) { program in
                    if !program.days.isEmpty { program.nextDay = (program.nextDay + 1) % program.days.count }
                }
            }
        }
        saveNow()
        return session
    }

    func discardWorkout() {
        data.activeSession = nil
    }

    func updateSession(_ id: UUID, _ change: (inout WorkoutSession) -> Void) {
        guard let index = data.sessions.firstIndex(where: { $0.id == id }) else { return }
        change(&data.sessions[index])
    }

    var completedSessions: [WorkoutSession] {
        data.sessions.filter { $0.endedAt != nil }.sorted { $0.startedAt > $1.startedAt }
    }

    // MARK: Coach context

    /// A plain-text briefing about the user for the AI coach.
    func coachContext() -> String {
        var lines: [String] = []
        let p = data.profile
        lines.append("PROFILE")
        if !p.name.isEmpty { lines.append("Name: \(p.name)") }
        if let age = p.age { lines.append("Age: \(age)") }
        if let w = p.weightKg { lines.append(String(format: "Weight: %.1f kg", w)) }
        if let h = p.heightCm { lines.append(String(format: "Height: %.0f cm", h)) }
        lines.append("Experience: \(p.experience.title). Goal: \(p.goal.title).")
        lines.append("Plan: \(p.daysPerWeek) sessions a week, about \(p.sessionMinutes) minutes each.")
        if !p.limitations.isEmpty { lines.append("Injuries / limitations: \(p.limitations)") }
        if !p.about.isEmpty { lines.append("In their words: \(p.about)") }

        if let health = data.health, !health.summaryLines.isEmpty {
            lines.append("\nAPPLE HEALTH")
            lines.append(contentsOf: health.summaryLines)
        }

        if let gym = activeGym {
            lines.append("\nCURRENT GYM: \(gym.name)\(gym.kind == .travel ? " (travelling — temporary)" : "")")
            lines.append("Equipment: " + gym.equipment.map { item in
                item.label.isEmpty ? item.type.displayName : "\(item.type.displayName) (\(item.label))"
            }.joined(separator: "; "))
        }

        if let program = activeProgram {
            lines.append("\nCURRENT PROGRAM: \(program.name)")
            for day in program.days {
                let items = day.exercises.map { "\(library.name($0.exerciseID)) \($0.sets)x\($0.repMin)-\($0.repMax)" }
                lines.append("\(day.name): " + items.joined(separator: ", "))
            }
        }

        let recent = completedSessions.prefix(8)
        if !recent.isEmpty {
            lines.append("\nRECENT SESSIONS (newest first; weight kg x reps @ effort where 6=easy, 7=solid, 9=hard, 10=max)")
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE d MMM"
            for session in recent {
                var header = "\(formatter.string(from: session.startedAt)) — \(session.dayName) at \(session.gymName), \(session.durationMinutes) min"
                if let effort = session.overallEffort { header += ", overall effort \(effort)/10" }
                if let hr = session.averageHeartRate { header += String(format: ", avg HR %.0f", hr) }
                lines.append(header)
                for item in session.exercises {
                    if item.skipped && item.sets.isEmpty {
                        lines.append("  \(library.name(item.exerciseID)): skipped")
                        continue
                    }
                    let sets = item.sets.map { "\(Coach.format($0.weightKg))x\($0.reps)@\($0.effort.rawValue)" }.joined(separator: " ")
                    var line = "  \(library.name(item.exerciseID)): \(sets)"
                    if let replaced = item.replacedExerciseID { line += " (swapped in for \(library.name(replaced)))" }
                    lines.append(line)
                }
                if !session.notes.isEmpty { lines.append("  Notes: \(session.notes)") }
            }
        }
        return lines.joined(separator: "\n")
    }
}

extension UIImage {
    /// JPEG data no larger than `maxEdge` on its long side: small enough to store and to send to the AI coach.
    func downscaledJPEG(maxEdge: CGFloat = 1400, quality: CGFloat = 0.72) -> Data? {
        let longest = max(size.width, size.height)
        let scale = longest > maxEdge ? maxEdge / longest : 1
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
