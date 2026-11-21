import Foundation

/// Every kind of gym equipment Spotter knows how to program around.
/// Raw values are used in the saved data, the bundled exercise library and the AI prompts.
enum EquipmentType: String, Codable, CaseIterable, Identifiable, Hashable {
    case dumbbells, barbell, ezBar, kettlebells
    case flatBench, adjustableBench, preacherBench, squatRack, smithMachine
    case cableStation, latPulldown, seatedCableRow
    case chestPressMachine, pecDeck, shoulderPressMachine, rowMachine, assistedPullupDip
    case legPress, hackSquat, legExtension, legCurl, hipAbAdMachine, calfRaiseMachine
    case abCrunchMachine, bicepCurlMachine, tricepMachine, backExtension
    case pullUpBar, dipStation
    case resistanceBands, exerciseBall, suspensionTrainer
    case treadmill, bike, rower, elliptical, stairClimber

    var id: String { rawValue }

    enum Category: String, CaseIterable, Identifiable {
        case freeWeights = "Free weights"
        case benchesRacks = "Benches & racks"
        case cables = "Cables"
        case upperMachines = "Upper-body machines"
        case lowerMachines = "Lower-body machines"
        case bodyweight = "Bodyweight & accessories"
        case cardio = "Cardio"
        var id: String { rawValue }
    }

    var category: Category {
        switch self {
        case .dumbbells, .barbell, .ezBar, .kettlebells: return .freeWeights
        case .flatBench, .adjustableBench, .preacherBench, .squatRack, .smithMachine: return .benchesRacks
        case .cableStation, .latPulldown, .seatedCableRow: return .cables
        case .chestPressMachine, .pecDeck, .shoulderPressMachine, .rowMachine, .assistedPullupDip,
             .abCrunchMachine, .bicepCurlMachine, .tricepMachine: return .upperMachines
        case .legPress, .hackSquat, .legExtension, .legCurl, .hipAbAdMachine, .calfRaiseMachine, .backExtension:
            return .lowerMachines
        case .pullUpBar, .dipStation, .resistanceBands, .exerciseBall, .suspensionTrainer: return .bodyweight
        case .treadmill, .bike, .rower, .elliptical, .stairClimber: return .cardio
        }
    }

    var displayName: String {
        switch self {
        case .dumbbells: return "Dumbbells"
        case .barbell: return "Barbell & plates"
        case .ezBar: return "EZ curl bar"
        case .kettlebells: return "Kettlebells"
        case .flatBench: return "Flat bench"
        case .adjustableBench: return "Adjustable bench"
        case .preacherBench: return "Preacher curl bench"
        case .squatRack: return "Squat / power rack"
        case .smithMachine: return "Smith machine"
        case .cableStation: return "Adjustable cable station"
        case .latPulldown: return "Lat pulldown"
        case .seatedCableRow: return "Seated cable row"
        case .chestPressMachine: return "Chest press machine"
        case .pecDeck: return "Pec deck / rear delt fly"
        case .shoulderPressMachine: return "Shoulder press machine"
        case .rowMachine: return "Seated row machine"
        case .assistedPullupDip: return "Assisted pull-up / dip"
        case .legPress: return "Leg press"
        case .hackSquat: return "Hack squat"
        case .legExtension: return "Leg extension"
        case .legCurl: return "Leg curl"
        case .hipAbAdMachine: return "Hip abductor / adductor"
        case .calfRaiseMachine: return "Calf raise machine"
        case .abCrunchMachine: return "Ab crunch machine"
        case .bicepCurlMachine: return "Biceps curl machine"
        case .tricepMachine: return "Triceps machine"
        case .backExtension: return "Back extension bench"
        case .pullUpBar: return "Pull-up bar"
        case .dipStation: return "Dip / knee-raise station"
        case .resistanceBands: return "Resistance bands"
        case .exerciseBall: return "Exercise ball"
        case .suspensionTrainer: return "Suspension trainer (TRX)"
        case .treadmill: return "Treadmill"
        case .bike: return "Exercise bike"
        case .rower: return "Rowing machine"
        case .elliptical: return "Elliptical"
        case .stairClimber: return "Stair climber"
        }
    }

    var symbol: String {
        switch category {
        case .freeWeights: return "dumbbell.fill"
        case .benchesRacks: return "square.split.bottomrightquarter"
        case .cables: return "cable.connector"
        case .upperMachines: return "figure.strengthtraining.traditional"
        case .lowerMachines: return "figure.strengthtraining.functional"
        case .bodyweight: return "figure.core.training"
        case .cardio: return "figure.run"
        }
    }

    var isCardio: Bool { category == .cardio }

    /// Gyms have lots of these, so when an exercise is blocked it's rarely because of them.
    var isPlentiful: Bool {
        switch self {
        case .dumbbells, .kettlebells, .resistanceBands, .exerciseBall: return true
        default: return false
        }
    }

    /// Owning this also covers these (an adjustable bench lies flat).
    var alsoCovers: [EquipmentType] {
        switch self {
        case .adjustableBench: return [.flatBench]
        default: return []
        }
    }
}

extension Set where Element == EquipmentType {
    /// Adds the equipment implied by what's in the set.
    var expanded: Set<EquipmentType> {
        var out = self
        for type in self { out.formUnion(type.alsoCovers) }
        return out
    }
}

enum GymPreset: String, CaseIterable, Identifiable {
    case commercial, hotel, bodyweight
    var id: String { rawValue }

    var title: String {
        switch self {
        case .commercial: return "Typical 24/7 gym"
        case .hotel: return "Basic hotel gym"
        case .bodyweight: return "No equipment"
        }
    }

    var equipment: [EquipmentType] {
        switch self {
        case .commercial:
            return [.dumbbells, .barbell, .ezBar, .kettlebells, .flatBench, .adjustableBench, .squatRack,
                    .smithMachine, .cableStation, .latPulldown, .seatedCableRow, .chestPressMachine, .pecDeck,
                    .shoulderPressMachine, .assistedPullupDip, .legPress, .legExtension, .legCurl,
                    .hipAbAdMachine, .abCrunchMachine, .backExtension, .pullUpBar, .exerciseBall,
                    .treadmill, .bike, .rower, .elliptical]
        case .hotel:
            return [.dumbbells, .adjustableBench, .exerciseBall, .treadmill, .bike]
        case .bodyweight:
            return []
        }
    }
}
