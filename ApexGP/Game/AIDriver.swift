import Foundation

/// Drives a car round the track: follows a lane, brakes for corners and
/// moves over to get past slower cars.
final class AIDriver {
    var skill: Float          // share of the grip it dares to use, ~0.8…1.0
    var lane: Float           // preferred offset from the centreline
    private var laneTarget: Float
    private var laneTimer: Float = 0

    init(skill: Float, lane: Float) {
        self.skill = skill
        self.lane = lane
        laneTarget = lane
    }

    func drive(car: CarPhysics, track: Track, others: [CarPhysics], dt: Float, rubberBand: Float = 1) -> DriveInput {
        // Pick a lane: drift towards the inside of upcoming corners, and
        // pull out to pass a slower car ahead.
        laneTimer -= dt
        if laneTimer <= 0 {
            laneTimer = Float.random(in: 2...5)
            laneTarget = Float.random(in: -0.45...0.45) * track.halfWidth
        }
        let ahead = track.curvature[track.index(atS: car.s + 40)]
        var target = laneTarget - clampf(ahead * 400, -1, 1) * track.halfWidth * 0.35

        var speedCap = Float.greatestFiniteMagnitude
        for other in others where other !== car {
            let gap = other.distance - car.distance
            if gap > 0 && gap < 18 && abs(other.d - car.d) < 2.4 {
                // Someone in the way: go round them if there's room, otherwise follow.
                let side: Float = other.d > 0 ? -1 : 1
                let candidate = other.d + side * 3.2
                if abs(candidate) < track.halfWidth - 1 {
                    target = candidate
                } else {
                    speedCap = min(speedCap, other.speed * 0.98)
                }
            }
        }
        lane += clampf(target - lane, -3 * dt, 3 * dt)

        // Steer at a point ahead on the lane.
        let look = 8 + abs(car.speed) * 0.45
        let aim = track.point(atS: car.s + look, offset: lane)
        let to = aim - car.pos
        let want = atan2(to.y, to.x)
        let err = wrapAngle(want - car.heading)
        let steer = clampf(err * 2.6, -1, 1)

        // Speed: look ahead for the slowest corner we need to be ready for.
        let mu = Float(car.perf.grip) * skill
        var vTarget = track.targetSpeed(atS: car.s + abs(car.speed) * 0.2 + 2) * mu.squareRoot()
        vTarget = min(vTarget * rubberBand, speedCap)
        var input = DriveInput(steer: steer)
        if car.speed < vTarget - 1 {
            input.throttle = 1
        } else if car.speed > vTarget + 1.5 {
            input.brake = clampf((car.speed - vTarget) / 8, 0.2, 1)
        } else {
            input.throttle = 0.3
        }
        // Back away from walls if stuck.
        if car.hitWall > 0 && car.speed < 2 {
            input.throttle = 1
        }
        return input
    }
}
