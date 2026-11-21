import Foundation
import UIKit

/// The places where the store calls out to the AI coach, each with an on-device fallback.
extension AppStore {
    struct ScanResult {
        var added: [EquipmentItem] = []
        var unrecognised: [String] = []
    }

    /// Sends photos of a gym to the AI coach, and returns the equipment it found with the best photo attached to each.
    func scanEquipment(photos: [UIImage]) async throws -> ScanResult {
        let jpegs = photos.compactMap { $0.downscaledJPEG() }
        guard !jpegs.isEmpty else { return ScanResult() }
        let scan = try await ClaudeClient().identifyEquipment(photos: jpegs)
        var files: [Int: String] = [:]
        var result = ScanResult(unrecognised: scan.unrecognised)
        for found in scan.items {
            guard let type = EquipmentType(rawValue: found.type) else { continue }
            var item = EquipmentItem(type: type, label: found.label, notes: found.notes)
            if jpegs.indices.contains(found.photo) {
                if files[found.photo] == nil { files[found.photo] = Self.savePhoto(jpegs[found.photo]) }
                item.photoFile = files[found.photo]
            }
            result.added.append(item)
        }
        return result
    }

    /// Designs a program for a gym: with the AI coach when a key is set, otherwise on-device.
    /// Returns a message when the AI coach was wanted but couldn't be used.
    @discardableResult
    func designProgram(for gym: Gym, extraRequest: String = "") async -> String? {
        guard Keychain.hasKey else {
            buildProgram(for: gym)
            return nil
        }
        var request: String
        if gym.kind == .travel, let home = homeProgram {
            let plan = home.days.map { day in
                "\(day.name): " + day.exercises.map { "\(library.name($0.exerciseID)) \($0.sets)x\($0.repMin)-\($0.repMax)" }.joined(separator: ", ")
            }.joined(separator: "\n")
            request = """
            I'm travelling and training at \(gym.name) for a short while. Design a temporary program for \
            this gym that keeps me on track with my usual plan below: same number of days, same structure \
            and training effect, substituting only what this gym can't support. The next session due is \
            day \(home.nextDay % max(home.days.count, 1) + 1) of the rotation, so keep the days in the same order.

            MY USUAL PROGRAM (\(home.name))
            \(plan)
            """
        } else {
            request = "Design my training program for \(gym.name)."
            if !completedSessions.isEmpty {
                request += " I've been training already (see the log) — build on what's working, fix what's stalled, and keep exercises I'm progressing on."
            }
        }
        if !extraRequest.isEmpty { request += "\n\nAlso: \(extraRequest)" }

        do {
            var program = try await ClaudeClient().designProgram(brief: coachContext(), request: request,
                                                                 gym: gym, library: library)
            if gym.kind == .travel, let home = homeProgram, program.days.count == home.days.count {
                program.nextDay = home.nextDay
            }
            setProgram(program)
            return nil
        } catch {
            if data.programs.last(where: { $0.gymID == gym.id }) == nil { buildProgram(for: gym) }
            return error.localizedDescription
        }
    }

    /// Pulls the latest numbers from Apple Health and fills any profile gaps from them.
    func refreshHealth() async {
        guard data.healthEnabled else { return }
        let snap = await HealthKitManager.shared.snapshot()
        data.health = snap
        if data.profile.weightKg == nil, let weight = snap.weightKg { data.profile.weightKg = (weight * 10).rounded() / 10 }
        if data.profile.heightCm == nil, let height = snap.heightCm { data.profile.heightCm = height.rounded() }
        if data.profile.age == nil, let age = snap.age { data.profile.age = age }
    }

    func connectHealth() async {
        let granted = await HealthKitManager.shared.requestAccess()
        data.healthEnabled = granted
        if granted { await refreshHealth() }
    }
}
