import SceneKit
import SpriteKit
import UIKit

enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case easy = "Easy", medium = "Medium", hard = "Hard"
    var id: String { rawValue }
    var skill: Float {
        switch self { case .easy: return 0.84; case .medium: return 0.92; case .hard: return 0.985 }
    }
    var powerScale: Double {
        switch self { case .easy: return 0.86; case .medium: return 0.96; case .hard: return 1.03 }
    }
}

struct RaceSettings: Codable, Equatable {
    var laps = 3
    var opponents = 5
    var difficulty = Difficulty.medium
    var drivingHelp = true

    private static let key = "ApexGP.raceSettings"
    static func load() -> RaceSettings {
        if let d = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(RaceSettings.self, from: d) { return s }
        return RaceSettings()
    }
    func save() {
        if let d = try? JSONEncoder().encode(self) { UserDefaults.standard.set(d, forKey: RaceSettings.key) }
    }
}

struct RaceResult: Identifiable {
    let id = UUID()
    var position: Int
    var name: String
    var car: String
    var color: UIColor
    var time: Double?
    var bestLap: Double?
    var isPlayer: Bool
}

enum BestLaps {
    private static let key = "ApexGP.bestLaps"
    static func get(_ trackID: String) -> Double? {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: Double])?[trackID]
    }
    /// Saves the lap if it's a new record. Returns true if it was.
    @discardableResult
    static func record(_ trackID: String, _ time: Double) -> Bool {
        var all = (UserDefaults.standard.dictionary(forKey: key) as? [String: Double]) ?? [:]
        if let old = all[trackID], old <= time { return false }
        all[trackID] = time
        UserDefaults.standard.set(all, forKey: key)
        return true
    }
}

private final class Racer {
    let physics: CarPhysics
    let node: CarNode
    var ai: AIDriver?
    let name: String
    let carName: String
    let color: UIColor
    let isPlayer: Bool
    var lapsDone = 0
    var lapStart: Double = 0
    var lastLap: Double?
    var bestLap: Double?
    var finishTime: Double?
    var stuckTime: Float = 0
    var wrongWayTime: Float = 0

    init(physics: CarPhysics, node: CarNode, ai: AIDriver?, name: String, carName: String, color: UIColor, isPlayer: Bool) {
        self.physics = physics
        self.node = node
        self.ai = ai
        self.name = name
        self.carName = carName
        self.color = color
        self.isPlayer = isPlayer
    }
}

/// Runs one race: builds the scene, reads input, moves every car each frame,
/// keeps score and drives the camera and HUD.
final class RaceController: NSObject, SCNSceneRendererDelegate {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    let hud: RaceHUD
    let track: Track
    let settings: RaceSettings
    var onFinish: (([RaceResult]) -> Void)?
    /// Set from the UI. The race freezes while true.
    var paused = false {
        didSet { if paused { sound?.update(rpm: 0.2, load: 0, squeal: 0, volume: 0) } }
    }

    private let trackScene: TrackScene
    private var racers: [Racer] = []
    private var player: Racer { racers[playerIndex] }
    private let playerIndex: Int
    private let input = InputReader()
    private var sound: EngineSound?

    private enum Phase { case countdown, racing, finished }
    private var phase = Phase.countdown
    private var clock: Double = 0
    private var raceTime: Double = 0
    private var goTime: Double = 0
    private var lastUpdate: TimeInterval = 0
    private var lightsShown = -1
    private var cameraMode = 0
    private var camPos = V3(0, 0, 0)
    private var camReady = false
    private var orderCache: [Racer] = []
    private var orderTimer: Float = 0
    private var reportedFinish = false
    private var finishTimer: Double = 0
    private var lastLapAnnounced = false

    private static let driverNames = ["Oscar", "Max", "Lando", "Charles", "Lewis", "George", "Fernando",
                                      "Kimi", "Isack", "Ollie", "Gabriel", "Pierre", "Alex", "Yuki", "Liam"]

    init(trackInfo: TrackInfo, settings: RaceSettings, playerCar: CarConfig, playerName: String) {
        self.settings = settings
        let track = Track(info: trackInfo)
        self.track = track

        // Grid: two staggered columns behind the line. Player starts mid-pack.
        let total = settings.opponents + 1
        let lane = min(2.8, track.halfWidth - 1.6)
        let slots: [(s: Float, d: Float)] = (0..<total).map { k in
            (s: -9 - Float(k) * 8, d: k % 2 == 0 ? -lane : lane)
        }
        let playerIndex = total / 2
        self.playerIndex = playerIndex
        trackScene = TrackScene(track: track, gridSlots: slots)

        var names = RaceController.driverNames.shuffled()
        var colors: [UIColor] = []
        var built: [Racer] = []
        let basePerf = playerCar.performance
        for k in 0..<total {
            let isPlayer = k == playerIndex
            var config: CarConfig
            var perf: Performance
            var ai: AIDriver? = nil
            if isPlayer {
                config = playerCar
                perf = basePerf
            } else {
                let model = CarCatalog.all.randomElement()!
                config = CarConfig.defaults(for: model)
                config.trimName = model.trims.randomElement()!.name
                config.paint = (model.paints + [specialPaints.randomElement()!]).randomElement()!
                config.wheelStyle = WheelStyle.allCases.randomElement()!
                config.wheelFinish = [WheelFinish.silver, .gloss, .gunmetal, .bronze].randomElement()!
                config.number = Int.random(in: 2...99)
                config.stripes = Double.random(in: 0...1) < 0.3 ? .racing : .none
                config.stripeColor = AccentColor.allCases.randomElement()!
                // Rivals get the player's performance, scaled by difficulty, so
                // every car you pick can win.
                let vary = Double.random(in: 0.97...1.03)
                perf = basePerf
                perf.powerW *= settings.difficulty.powerScale * vary
                perf.topSpeed *= pow(settings.difficulty.powerScale * vary, 1.0 / 3.0)
                ai = AIDriver(skill: settings.difficulty.skill * Float.random(in: 0.98...1.01),
                              lane: slots[k].d)
            }
            let physics = CarPhysics(perf: perf, model: config.model)
            physics.isElectric = ["model3", "ioniq5n"].contains(config.modelID)
            physics.place(on: track, s: slots[k].s, d: slots[k].d)
            let node = CarNode(config: config)
            let color = UIColor(config.paint.color)
            colors.append(color)
            let name = isPlayer ? (playerName.isEmpty ? "You" : playerName) : names.removeFirst()
            built.append(Racer(physics: physics, node: node, ai: ai, name: name, carName: config.model.displayName,
                               color: color, isPlayer: isPlayer))
        }
        racers = built
        hud = RaceHUD(size: CGSize(width: 1920, height: 1080), track: track, carColors: colors, playerIndex: playerIndex)

        super.init()

        trackScene.applyEnvironment(to: scene)
        scene.rootNode.addChildNode(trackScene.node)
        for r in racers { scene.rootNode.addChildNode(r.node.root) }

        let camera = SCNCamera()
        camera.zNear = 0.2
        camera.zFar = 2200
        camera.fieldOfView = 62
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)

        sound = EngineSound(electric: player.physics.isElectric)
        orderCache = racers
        syncNodes(dt: 0)
        trackScene.setStartLights(0)
    }

    func stop() {
        sound?.stop()
        sound = nil
    }

    // MARK: Frame

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if lastUpdate == 0 { lastUpdate = time }
        let dt = Float(min(1.0 / 20, max(0, time - lastUpdate)))
        lastUpdate = time
        if paused || dt <= 0 { return }
        step(dt)
    }

    private func step(_ dt: Float) {
        clock += Double(dt)
        let pad = input.read()
        if pad.cameraPressed { cameraMode = (cameraMode + 1) % 3 }

        switch phase {
        case .countdown:
            let lit = min(5, Int(clock / 0.9))
            if lit != lightsShown {
                lightsShown = lit
                trackScene.setStartLights(lit)
                hud.setLights(lit, visible: true)
                if lit == 5 { goTime = clock + Double.random(in: 0.5...1.5) }
            }
            if lit == 5 && clock >= goTime {
                phase = .racing
                trackScene.setStartLights(0)
                hud.setLights(0, visible: false)
                hud.flash("GO!", color: UIColor(red: 0.3, green: 1, blue: 0.3, alpha: 1))
                hud.setHint("")
            }
            if clock < 0.1 {
                hud.setHint(input.usingRemote
                            ? "Slide on the touch surface to steer · Click to brake · Play/Pause for camera · Menu to pause"
                            : "Left stick steers · Right trigger accelerates · Left trigger brakes · Y for camera")
            }
            // Rev the engine on the grid.
            let rev = max(pad.throttle, pad.hasThrottleControl ? 0 : 0.3)
            sound?.update(rpm: 0.2 + rev * 0.5, load: rev, squeal: 0, volume: 0.8)
        case .racing, .finished:
            raceTime += Double(dt)
            for r in racers {
                let control: DriveInput
                if let ai = r.ai {
                    control = ai.drive(car: r.physics, track: track, others: racers.map(\.physics), dt: dt,
                                       rubberBand: rubberBand(for: r))
                } else {
                    control = playerControl(pad, dt: dt)
                }
                r.physics.step(dt: dt, input: control, track: track)
                if r.isPlayer { lastPlayerInput = control }
            }
            collideCars()
            for r in racers { scoreLaps(r) ; checkStuck(r, dt: dt) }
            if phase == .finished {
                finishTimer += Double(dt)
                if finishTimer > 4 && !reportedFinish {
                    reportedFinish = true
                    let results = buildResults()
                    DispatchQueue.main.async { self.onFinish?(results) }
                }
            }
            let p = player.physics
            let eng = p.engine
            sound?.update(rpm: eng.rpm, load: lastPlayerInput.throttle, squeal: min(1, p.sliding * min(1, abs(p.speed) / 15)),
                          volume: 0.85)
        }
        syncNodes(dt: dt)
        updateCamera(dt: dt)
        updateHUD(dt: dt)
    }

    private var lastPlayerInput = DriveInput()
    private var assistLane: Float = 0

    private func playerControl(_ pad: InputReader.State, dt: Float) -> DriveInput {
        let car = player.physics
        var out = DriveInput(steer: pad.steer, throttle: pad.throttle, brake: pad.brake)
        if !pad.hasThrottleControl || settings.drivingHelp {
            out.throttle = pad.brake > 0.1 ? 0 : 1
        }
        if settings.drivingHelp && car.speed > 2 {
            // Steering help: follow the road at the current distance from the middle.
            assistLane = clampf(car.d, -(track.halfWidth - 1.2), track.halfWidth - 1.2)
            let look = 9 + abs(car.speed) * 0.4
            let aim = track.point(atS: car.s + look, offset: assistLane)
            let to = aim - car.pos
            let err = wrapAngle(atan2(to.y, to.x) - car.heading)
            let assist = clampf(err * 2.4, -1, 1)
            out.steer = clampf(assist * 0.85 + pad.steer * 0.9, -1, 1)
            // Braking help: don't arrive at a corner too fast.
            let target = track.targetSpeed(atS: car.s + abs(car.speed) * 0.25 + 2) * Float(car.perf.grip).squareRoot() * 1.03
            if car.speed > target + 1 {
                out.throttle = 0
                out.brake = max(out.brake, clampf((car.speed - target) / 6, 0.3, 1))
            }
        }
        return out
    }

    private func rubberBand(for r: Racer) -> Float {
        let gap = r.physics.distance - player.physics.distance
        switch settings.difficulty {
        case .easy: return gap > 120 ? 0.88 : (gap < -200 ? 1.04 : 1)
        case .medium: return gap > 250 ? 0.94 : (gap < -300 ? 1.03 : 1)
        case .hard: return 1
        }
    }

    private func collideCars() {
        for i in 0..<racers.count {
            for j in (i + 1)..<racers.count {
                let a = racers[i].physics, b = racers[j].physics
                var ds = b.s - a.s
                if ds > track.length / 2 { ds -= track.length }
                if ds < -track.length / 2 { ds += track.length }
                let dd = b.d - a.d
                let needS = a.halfLength + b.halfLength - 0.2
                let needD = a.halfWidth + b.halfWidth
                guard abs(ds) < needS && abs(dd) < needD else { continue }
                let overS = needS - abs(ds), overD = needD - abs(dd)
                if overD < overS * 0.6 {
                    // Side by side: nudge apart.
                    let push = overD / 2 + 0.02
                    let sign: Float = dd >= 0 ? 1 : -1
                    a.d -= push * sign
                    b.d += push * sign
                    a.pos = track.point(atS: a.s, offset: a.d)
                    b.pos = track.point(atS: b.s, offset: b.d)
                    a.speed *= 0.995
                    b.speed *= 0.995
                } else {
                    // Nose to tail: the car behind is held back.
                    let (front, rear) = ds > 0 ? (b, a) : (a, b)
                    rear.pos -= rear.forward * overS
                    rear.speed = min(rear.speed, front.speed * 0.97)
                    front.speed += 0.15
                }
            }
        }
    }

    private func scoreLaps(_ r: Racer) {
        let done = Int(floor(r.physics.distance / track.length))
        guard done > r.lapsDone, done >= 1 else { return }
        r.lapsDone = done
        let lap = raceTime - r.lapStart
        r.lapStart = raceTime
        r.lastLap = lap
        if r.bestLap == nil || lap < r.bestLap! { r.bestLap = lap }

        if r.lapsDone >= settings.laps && r.finishTime == nil {
            r.finishTime = raceTime
        }
        guard r.isPlayer else { return }
        let record = BestLaps.record(track.info.id, lap)
        if r.finishTime != nil {
            phase = .finished
            r.ai = AIDriver(skill: 0.7, lane: r.physics.d)
            let pos = position(of: r)
            let suffix = ["st", "nd", "rd"]
            let ord = pos <= 3 ? "\(pos)\(suffix[pos - 1])" : "\(pos)th"
            hud.flash(pos == 1 ? "YOU WIN!" : "FINISHED \(ord)", sub: "Time \(RaceHUD.format(raceTime))", seconds: 4,
                      color: pos == 1 ? UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1) : .white)
        } else if record {
            hud.flash("NEW RECORD", sub: RaceHUD.format(lap), color: UIColor(red: 0.8, green: 0.4, blue: 1, alpha: 1))
        } else if r.lapsDone == settings.laps - 1 && !lastLapAnnounced {
            lastLapAnnounced = true
            hud.flash("FINAL LAP", sub: "Lap \(RaceHUD.format(lap))")
        } else {
            hud.flash("LAP \(r.lapsDone + 1)", sub: RaceHUD.format(lap), seconds: 1.2)
        }
    }

    private func checkStuck(_ r: Racer, dt: Float) {
        let p = r.physics
        if abs(p.speed) < 2.5 && (p.onGrass || p.hitWall > 0 || r.ai != nil) {
            r.stuckTime += dt
        } else {
            r.stuckTime = 0
        }
        let t = track.tangentAt(s: p.s)
        let rel = abs(wrapAngle(p.heading - atan2(t.y, t.x)))
        if rel > 2.1 && p.speed > 3 {
            r.wrongWayTime += dt
        } else {
            r.wrongWayTime = max(0, r.wrongWayTime - dt * 2)
        }
        if r.isPlayer && r.wrongWayTime > 1.2 && phase == .racing {
            hud.flash("WRONG WAY", seconds: 0.5, color: UIColor(red: 1, green: 0.3, blue: 0.2, alpha: 1))
        }
        if r.stuckTime > 3 || r.wrongWayTime > 6 {
            // Put the car back on the road, facing the right way.
            let dist = p.distance
            p.place(on: track, s: p.s, d: clampf(p.d, -2, 2))
            p.distance = dist
            r.stuckTime = 0
            r.wrongWayTime = 0
        }
    }

    // MARK: Order and results

    private func ordered() -> [Racer] {
        racers.sorted { a, b in
            switch (a.finishTime, b.finishTime) {
            case let (x?, y?): return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.physics.distance > b.physics.distance
            }
        }
    }

    private func position(of r: Racer) -> Int {
        (ordered().firstIndex { $0 === r } ?? 0) + 1
    }

    private func buildResults() -> [RaceResult] {
        ordered().enumerated().map { i, r in
            RaceResult(position: i + 1, name: r.name, car: r.carName, color: r.color, time: r.finishTime,
                       bestLap: r.bestLap, isPlayer: r.isPlayer)
        }
    }

    // MARK: Visuals

    private func syncNodes(dt: Float) {
        for r in racers {
            let p = r.physics
            let n = r.node
            n.root.position = SCNVector3(p.pos.x, p.y, p.pos.y)
            n.root.eulerAngles.y = -p.heading
            let roll = clampf(-p.lateralAccel / CarPhysics.g * 0.035, -0.06, 0.06)
            let pitch = clampf(-p.longAccel / CarPhysics.g * 0.025, -0.04, 0.04)
            n.update(speed: p.speed, steer: p.steer, dt: dt, roll: roll, pitch: pitch,
                     braking: (r.isPlayer ? lastPlayerInput.brake : 0) > 0.1 || p.longAccel < -4)
        }
    }

    private func updateCamera(dt: Float) {
        let p = player.physics
        let f = V3(cos(p.heading), 0, sin(p.heading))
        let carPos = V3(p.pos.x, p.y, p.pos.y)
        var desired: V3
        var look: V3
        if phase == .countdown {
            // Swing round from the front of the car to behind it.
            let t = Float(min(1, clock / 4))
            let ease = t * t * (3 - 2 * t)
            let a = (1 - ease) * .pi * 0.85
            let back = V2(-f.x, -f.z)
            let dir = V2(back.x * cos(a) - back.y * sin(a), back.x * sin(a) + back.y * cos(a))
            let dist = 6 + ease * 2.5
            desired = carPos + V3(dir.x, 0, dir.y) * dist + V3(0, 1.4 + ease * 1.6, 0)
            look = carPos + V3(0, 0.8, 0) + f * (ease * 4)
            camPos = desired
            camReady = true
        } else {
            switch cameraMode {
            case 1:
                desired = carPos - f * 14 + V3(0, 5.5, 0)
                look = carPos + f * 6 + V3(0, 0.5, 0)
            case 2:
                desired = carPos + f * 0.3 + V3(0, 1.25, 0)
                look = carPos + f * 25 + V3(0, 0.9, 0)
            default:
                desired = carPos - f * 8.5 + V3(0, 2.9, 0)
                look = carPos + f * 5 + V3(0, 1.0, 0)
            }
            if cameraMode == 2 || !camReady {
                camPos = desired
                camReady = true
            } else {
                let k = 1 - exp(-dt * 7)
                camPos += (desired - camPos) * k
                camPos.y = max(camPos.y, p.y + 1.0)
            }
        }
        cameraNode.position = camPos.scn
        cameraNode.look(at: look.scn, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        let speedFov = 60 + CGFloat(min(abs(p.speed), 90) / 90) * 14
        cameraNode.camera?.fieldOfView = cameraMode == 2 ? speedFov + 6 : speedFov
    }

    private func updateHUD(dt: Float) {
        orderTimer -= dt
        if orderTimer <= 0 {
            orderTimer = 0.25
            orderCache = ordered()
        }
        let pr = player
        let pos = (orderCache.firstIndex { $0 === pr } ?? 0) + 1
        let eng = pr.physics.engine
        hud.update(position: pos,
                   laps: (current: pr.lapsDone + 1, total: settings.laps),
                   raceTime: pr.finishTime ?? raceTime,
                   lastLap: pr.lastLap,
                   bestLap: pr.bestLap,
                   speedKmh: Int(abs(pr.physics.speed) * 3.6),
                   gear: pr.physics.speed < -0.5 ? 0 : eng.gear,
                   cars: racers.map { (pos: $0.physics.pos, color: $0.color) },
                   order: orderCache.map { (name: $0.name, color: $0.color, isPlayer: $0.isPlayer) })
    }
}
