import Foundation

enum MovementPattern: String, Codable, CaseIterable, Hashable {
    case horizontalPush, inclinePush, verticalPush, horizontalPull, verticalPull
    case squat, lunge, hinge, glute, kneeExtension, kneeFlexion
    case chestFly, lateralRaise, rearDelt, bicepCurl, tricepExt, calf, core
    case hipAbduction, hipAdduction

    var title: String {
        switch self {
        case .horizontalPush: return "Chest press"
        case .inclinePush: return "Incline press"
        case .verticalPush: return "Overhead press"
        case .horizontalPull: return "Row"
        case .verticalPull: return "Pulldown / pull-up"
        case .squat: return "Squat"
        case .lunge: return "Single-leg"
        case .hinge: return "Hip hinge"
        case .glute: return "Glutes"
        case .kneeExtension: return "Quads"
        case .kneeFlexion: return "Hamstrings"
        case .chestFly: return "Chest fly"
        case .lateralRaise: return "Side delts"
        case .rearDelt: return "Rear delts"
        case .bicepCurl: return "Biceps"
        case .tricepExt: return "Triceps"
        case .calf: return "Calves"
        case .core: return "Core"
        case .hipAbduction: return "Outer hips"
        case .hipAdduction: return "Inner thighs"
        }
    }

    /// Patterns that train similar muscles, used when nothing in the same pattern is possible.
    var fallbacks: [MovementPattern] {
        switch self {
        case .horizontalPush: return [.inclinePush, .chestFly]
        case .inclinePush: return [.horizontalPush, .verticalPush]
        case .verticalPush: return [.inclinePush, .lateralRaise]
        case .horizontalPull: return [.verticalPull, .rearDelt]
        case .verticalPull: return [.horizontalPull]
        case .squat: return [.lunge, .kneeExtension]
        case .lunge: return [.squat, .glute]
        case .hinge: return [.glute, .kneeFlexion]
        case .glute: return [.hinge, .lunge]
        case .kneeExtension: return [.squat, .lunge]
        case .kneeFlexion: return [.hinge, .glute]
        case .chestFly: return [.horizontalPush, .inclinePush]
        case .lateralRaise: return [.verticalPush]
        case .rearDelt: return [.horizontalPull]
        case .bicepCurl: return [.verticalPull]
        case .tricepExt: return [.horizontalPush]
        case .calf: return []
        case .core: return []
        case .hipAbduction: return [.glute]
        case .hipAdduction: return [.lunge]
        }
    }

    var isLowerBody: Bool {
        switch self {
        case .squat, .lunge, .hinge, .glute, .kneeExtension, .kneeFlexion, .calf, .hipAbduction, .hipAdduction:
            return true
        default:
            return false
        }
    }
}

enum LoadType: String, Codable {
    case weighted, bodyweight, timed
}

struct Exercise: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var pattern: MovementPattern
    /// Any one of these equipment sets is enough. An empty set means no equipment.
    var requiresAny: [[EquipmentType]]
    var primaryMuscles: [String]
    var secondaryMuscles: [String]
    var instructions: [String]
    var compound: Bool
    /// 1 = anyone, 3 = needs skill or strength.
    var difficulty: Int
    /// 1 = staple, 3 = fallback.
    var tier: Int
    var loadType: LoadType
    var images: [String]

    /// The equipment set you'd use for this exercise given what's available, or nil if you can't do it.
    func equipment(in available: Set<EquipmentType>, excluding busy: Set<EquipmentType> = []) -> [EquipmentType]? {
        requiresAny.first { set in
            set.allSatisfy { available.contains($0) && !isBlocked($0, busy: busy) }
        }
    }

    private func isBlocked(_ type: EquipmentType, busy: Set<EquipmentType>) -> Bool {
        if busy.contains(type) { return true }
        // A busy adjustable bench only blocks flat-bench work if there's no real flat bench free;
        // we can't know, so treat benches independently.
        return false
    }

    var needsNoEquipment: Bool { requiresAny.contains { $0.isEmpty } }

    var equipmentSummary: String {
        if needsNoEquipment && requiresAny.count == 1 { return "No equipment" }
        let sets = requiresAny.filter { !$0.isEmpty }
        return sets.map { $0.map(\.displayName).joined(separator: " + ") }.joined(separator: " or ")
    }

    var muscleSummary: String {
        primaryMuscles.map(\.capitalized).joined(separator: ", ")
    }
}

final class ExerciseLibrary {
    static let shared = ExerciseLibrary()

    let all: [Exercise]
    private let byID: [String: Exercise]

    init() {
        var loaded: [Exercise] = []
        if let url = Bundle.main.url(forResource: "exercises", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Exercise].self, from: data) {
            loaded = decoded
        }
        all = loaded
        byID = Dictionary(loaded.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    subscript(id: String) -> Exercise? { byID[id] }

    func name(_ id: String) -> String { byID[id]?.name ?? id.replacingOccurrences(of: "_", with: " ") }

    func exercises(using type: EquipmentType) -> [Exercise] {
        all.filter { ex in ex.requiresAny.contains { $0.contains(type) } }
            .sorted { ($0.tier, $0.name) < ($1.tier, $1.name) }
    }

    func available(in equipment: Set<EquipmentType>) -> [Exercise] {
        all.filter { $0.equipment(in: equipment) != nil }
    }
}
