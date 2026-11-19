import Foundation

/// Everything the player has chosen for their car. Saved between launches.
struct CarConfig: Codable, Equatable {
    var modelID: String
    var trimName: String
    var paint: Paint
    var wheelStyle: WheelStyle = .fiveSpoke
    var wheelFinish: WheelFinish = .silver
    var wheelInches: Int
    var caliper: CaliperColor = .red
    var stripes: StripeStyle = .none
    var stripeColor: AccentColor = .white
    var roof: RoofStyle = .body
    var wing: WingStyle = .factory
    var number: Int = 7

    var model: CarModel { CarCatalog.model(id: modelID) }
    var trim: Trim { model.trims.first { $0.name == trimName } ?? model.trims[0] }

    /// Whether a rear wing is fitted, and which kind.
    var effectiveWing: WingStyle {
        if wing == .factory { return trim.factoryWing ? .gt : .none }
        return wing
    }

    static let wheelSizes = [17, 18, 19, 20, 21, 22]

    static func defaults(for model: CarModel) -> CarConfig {
        CarConfig(modelID: model.id, trimName: model.trims[0].name, paint: model.paints[0],
                  wheelInches: model.defaultWheelInches,
                  roof: model.style == .roadster ? .black : .body)
    }

    /// Switches to another car, keeping wheel/stripe choices that still make sense.
    mutating func switchModel(to newModel: CarModel) {
        var next = CarConfig.defaults(for: newModel)
        next.wheelStyle = wheelStyle
        next.wheelFinish = wheelFinish
        next.caliper = caliper
        next.stripes = stripes
        next.stripeColor = stripeColor
        next.number = number
        self = next
    }

    var performance: Performance { Performance(trim: trim, wing: effectiveWing, wheelInches: wheelInches) }

    // MARK: Saving

    private static let key = "ApexGP.carConfig"

    static func load() -> CarConfig {
        if let data = UserDefaults.standard.data(forKey: key),
           let cfg = try? JSONDecoder().decode(CarConfig.self, from: data),
           CarCatalog.all.contains(where: { $0.id == cfg.modelID }) {
            return cfg
        }
        return defaults(for: CarCatalog.all[0])
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: CarConfig.key)
        }
    }
}

/// The numbers the physics uses, derived from a trim plus the player's add-ons.
struct Performance {
    var powerW: Double
    var massKg: Double
    var topSpeed: Double      // m/s
    var grip: Double          // g
    var downforce: Double     // extra grip per (m/s)^2
    var tractionShare: Double // share of weight on driven wheels

    init(trim: Trim, wing: WingStyle, wheelInches: Int) {
        powerW = trim.powerKW * 1000
        massKg = trim.massKg
        var top = trim.topSpeedKmh / 3.6
        var g = trim.grip
        var df = 0.0
        switch wing {
        case .gt:
            df = 0.000035
            if !trim.factoryWing { top *= 0.97 }
        case .lip:
            df = 0.000012
        case .none, .factory:
            if trim.factoryWing { top *= 1.02; g -= 0.03 }
        }
        // Bigger wheels: a touch more grip, a touch slower to spin up.
        g += Double(wheelInches - 18) * 0.004
        topSpeed = top
        grip = g
        downforce = df
        switch trim.drive {
        case .awd: tractionShare = 1.0
        case .rwd: tractionShare = 0.62
        case .fwd: tractionShare = 0.58
        }
    }

    init(powerW: Double, massKg: Double, topSpeed: Double, grip: Double, downforce: Double, tractionShare: Double) {
        self.powerW = powerW
        self.massKg = massKg
        self.topSpeed = topSpeed
        self.grip = grip
        self.downforce = downforce
        self.tractionShare = tractionShare
    }

    /// Simulated 0–100 km/h time with the same model the game uses.
    var zeroToHundred: Double {
        var v = 0.0, t = 0.0
        let dt = 0.01
        while v < 100 / 3.6 && t < 30 {
            v += CarPhysics.acceleration(perf: self, speed: v, throttle: 1, brake: 0, surfaceDrag: 0) * dt
            t += dt
        }
        return t + 0.25 // launch/shift time
    }
}
