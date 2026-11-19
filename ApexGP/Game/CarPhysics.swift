import Foundation

struct DriveInput {
    var steer: Float = 0     // -1 left … +1 right
    var throttle: Float = 0  // 0…1
    var brake: Float = 0     // 0…1
}

/// Simple, forgiving arcade car: grip-limited cornering, power-limited
/// acceleration and drag that settles at the car's real top speed.
final class CarPhysics {
    static let g: Float = 9.81

    var perf: Performance
    let wheelbase: Float
    let halfLength: Float
    let halfWidth: Float

    // State
    var pos = V2(0, 0)
    var y: Float = 0
    var heading: Float = 0
    var speed: Float = 0
    var steer: Float = 0
    var yawRate: Float = 0
    var lateralAccel: Float = 0
    var longAccel: Float = 0
    var onGrass = false
    var hitWall: Float = 0       // > 0 for a moment after touching a wall
    var sliding: Float = 0       // 0…1, how hard the tyres are working

    // Where it is on the track
    var trackIndex = -1
    var s: Float = 0
    var d: Float = 0
    /// Total distance covered along the track since the start line (can be negative on the grid).
    var distance: Float = 0

    init(perf: Performance, model: CarModel) {
        self.perf = perf
        wheelbase = Float(model.wheelbaseM)
        halfLength = Float(model.lengthM) / 2
        halfWidth = Float(model.widthM) / 2
    }

    var forward: V2 { V2(cos(heading), sin(heading)) }

    static func acceleration(perf: Performance, speed: Double, throttle: Double, brake: Double, surfaceDrag: Double) -> Double {
        let gD = Double(g)
        let v = max(abs(speed), 1.0)
        let dragCoef = perf.powerW / pow(perf.topSpeed, 3)
        let traction = perf.grip * gD * perf.massKg * perf.tractionShare * 1.1
        let drive = min(throttle * perf.powerW / v, traction)
        var a = drive / perf.massKg
        a -= dragCoef * speed * abs(speed) / perf.massKg
        a -= 0.012 * gD * (speed > 0 ? 1 : 0)
        a -= surfaceDrag * speed
        a -= brake * (perf.grip * 1.05 + 0.1) * gD * (speed > 0 ? 1 : 0)
        return a
    }

    func place(on track: Track, s: Float, d: Float) {
        self.s = track.wrapS(s)
        self.d = d
        distance = s
        let p = track.point(atS: s, offset: d)
        pos = p
        y = track.heightAt(s: s)
        let t = track.tangentAt(s: s)
        heading = atan2(t.y, t.x)
        speed = 0
        steer = 0
        trackIndex = track.index(atS: s)
    }

    func step(dt: Float, input: DriveInput, track: Track) {
        // Steering eases in and gets gentler with speed.
        let steerRate: Float = 3.2
        steer += clampf(input.steer - steer, -steerRate * dt, steerRate * dt)

        let surfaceLimit = track.halfWidth + 1.2
        onGrass = abs(d) > surfaceLimit
        let gripFactor: Float = onGrass ? 0.6 : 1.0
        let surfaceDrag: Double = onGrass ? 0.35 : 0

        // Longitudinal
        var throttle = Double(input.throttle)
        var brake = Double(input.brake)
        if speed < 0.5 && input.brake > 0.3 && input.throttle < 0.1 {
            // Reverse when stopped and holding brake.
            throttle = 0; brake = 0
            speed = max(-8, speed - 4 * dt)
        } else if speed < 0 {
            speed = min(0, speed + (input.throttle > 0 ? 10 : 3) * dt)
        }
        if speed >= 0 {
            let a = Float(CarPhysics.acceleration(perf: perf, speed: Double(speed), throttle: throttle, brake: brake, surfaceDrag: surfaceDrag))
            longAccel = a
            speed = max(0, speed + a * dt)
        }

        // Lateral: the yaw the driver asks for, limited by grip.
        let v = speed
        let maxSteerAngle: Float = 0.55 / (1 + abs(v) / 28)
        let wanted = v * tan(steer * maxSteerAngle) / wheelbase
        let gripG = (Float(perf.grip) * gripFactor + Float(perf.downforce) * v * v) * CarPhysics.g
        let maxYaw = gripG / max(abs(v), 1)
        let actual = clampf(wanted, -maxYaw, maxYaw)
        sliding = abs(wanted) > 0.01 ? clampf((abs(wanted) - maxYaw * 0.85) / max(maxYaw * 0.5, 0.01), 0, 1) : 0
        if abs(wanted) > maxYaw {
            // Asking for more than the tyres have: scrub some speed.
            speed -= min(speed, (abs(wanted) - maxYaw) * abs(v) * 0.35 * dt)
        }
        yawRate += (actual - yawRate) * min(1, dt * 12)
        lateralAccel = yawRate * v
        heading = wrapAngle(heading + yawRate * dt)

        if onGrass && v > 3 {
            // A little wobble on the grass.
            heading += Float.random(in: -0.15...0.15) * dt * min(1, v / 20)
        }

        pos += forward * (speed * dt)

        // Where are we now?
        let prevS = s
        let loc = track.locate(pos, hint: trackIndex)
        trackIndex = loc.index
        s = loc.s
        d = loc.d
        var ds = s - prevS
        if ds > track.length / 2 { ds -= track.length }
        if ds < -track.length / 2 { ds += track.length }
        distance += ds
        y = track.heightAt(s: s)

        hitWall = max(0, hitWall - dt)
        collideWithWalls(track: track)
    }

    private func collideWithWalls(track: Track) {
        let lim = track.limits(atS: s)
        let margin = halfWidth + 0.15
        var wall: Float? = nil
        if d > lim.right - margin { wall = lim.right - margin }
        if d < -(lim.left - margin) { wall = -(lim.left - margin) }
        guard let newD = wall else { return }

        let t = track.tangentAt(s: s)
        let trackHeading = atan2(t.y, t.x)
        var rel = wrapAngle(heading - trackHeading)
        let backwards = abs(rel) > .pi / 2
        let impact = abs(sin(rel))
        speed *= max(0.35, 1 - impact * 1.1 - 0.05)
        // Turn the car to run along the wall.
        if backwards {
            rel = wrapAngle(rel - .pi)
        }
        heading = wrapAngle(heading - rel * 0.6)
        yawRate = 0
        d = newD
        pos = track.point(atS: s, offset: d)
        hitWall = 0.3
    }

    // MARK: Engine note

    var isElectric = false

    /// (rpm 0…1, gear) for the engine sound and the HUD.
    var engine: (rpm: Float, gear: Int) {
        let top = Float(perf.topSpeed)
        let v = abs(speed)
        if isElectric { return (min(1, 0.15 + v / top), 1) }
        let ratios: [Float] = [0.28, 0.42, 0.56, 0.70, 0.84, 1.0]
        for (i, r) in ratios.enumerated() {
            let gearTop = top * r
            if v < gearTop * 0.96 || i == ratios.count - 1 {
                let lower = i == 0 ? 0 : top * ratios[i - 1] * 0.7
                let t = clampf((v - lower) / max(gearTop - lower, 1), 0, 1)
                return (0.2 + 0.8 * t, i + 1)
            }
        }
        return (1, 6)
    }
}
