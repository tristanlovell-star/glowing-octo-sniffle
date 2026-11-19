import Foundation

typealias V2 = SIMD2<Float>
typealias V3 = SIMD3<Float>

extension SIMD2 where Scalar == Float {
    var len: Float { (x * x + y * y).squareRoot() }
    var norm: V2 { let l = len; return l > 1e-6 ? self / l : V2(1, 0) }
    func dot(_ o: V2) -> Float { x * o.x + y * o.y }
    /// Right-hand perpendicular when x is east and y (z) is south.
    var right: V2 { V2(-y, x) }
}

extension SIMD3 where Scalar == Float {
    var len: Float { (x * x + y * y + z * z).squareRoot() }
    var norm: V3 { let l = len; return l > 1e-6 ? self / l : V3(0, 1, 0) }
}

func lerpf(_ a: Float, _ b: Float, _ t: Float) -> Float { a + (b - a) * t }
func clampf(_ v: Float, _ lo: Float, _ hi: Float) -> Float { min(max(v, lo), hi) }
func wrapAngle(_ a: Float) -> Float {
    var x = a
    while x > .pi { x -= 2 * .pi }
    while x < -.pi { x += 2 * .pi }
    return x
}

// MARK: - Track data (from tracks.json)

struct TrackInfo: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var fullName: String
    var country: String
    var flag: String
    var lengthMeters: Int
    var width: Double
    var points: [[Double]]
    var heights: [Double]?

    var lengthText: String { String(format: "%.3f km", Double(lengthMeters) / 1000) }

    /// Street circuits get walls close to the road.
    var isStreetCircuit: Bool {
        ["mc-1929", "az-2016", "sg-2008", "sa-2021", "us-2023", "ca-1978", "us-2022", "es-2026", "au-1953"].contains(id)
    }

    static func == (a: TrackInfo, b: TrackInfo) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

private struct TrackFile: Codable {
    var tracks: [TrackInfo]
}

enum TrackLibrary {
    static let all: [TrackInfo] = {
        guard let url = Bundle.main.url(forResource: "tracks", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(TrackFile.self, from: data) else {
            return []
        }
        return file.tracks
    }()
}

// MARK: - Processed track

/// A circuit resampled into evenly spaced points with everything the game
/// needs to know at each one: direction, curvature, walls and a target speed.
final class Track {
    let info: TrackInfo
    let count: Int
    let spacing: Float
    let length: Float
    let halfWidth: Float

    private(set) var pos: [V2] = []
    private(set) var height: [Float] = []
    private(set) var tangent: [V2] = []
    private(set) var curvature: [Float] = []   // +ve turns right, 1/m
    /// Distance from the centreline to the wall on each side.
    private(set) var leftLimit: [Float] = []
    private(set) var rightLimit: [Float] = []
    /// Fastest sensible speed (m/s) at each point for a car with 1.0 g of grip.
    private(set) var speedProfile: [Float] = []

    init(info: TrackInfo) {
        self.info = info
        halfWidth = Float(info.width) / 2

        // 1. Raw points, dropping duplicates.
        var raw: [V2] = []
        var rawH: [Float] = []
        for (i, p) in info.points.enumerated() {
            let v = V2(Float(p[0]), Float(p[1]))
            if let last = raw.last, (v - last).len < 0.5 { continue }
            raw.append(v)
            rawH.append(Float(info.heights?[i] ?? 0))
        }

        // 2. Dense centripetal Catmull-Rom curve through them.
        var dense: [V2] = []
        var denseH: [Float] = []
        let n = raw.count
        for i in 0..<n {
            let p0 = raw[(i - 1 + n) % n], p1 = raw[i], p2 = raw[(i + 1) % n], p3 = raw[(i + 2) % n]
            let h1 = rawH[i], h2 = rawH[(i + 1) % n]
            let segLen = (p2 - p1).len
            let steps = max(2, Int(segLen / 1.0))
            for k in 0..<steps {
                let u = Float(k) / Float(steps)
                dense.append(Track.catmullRom(p0, p1, p2, p3, u))
                denseH.append(lerpf(h1, h2, u))
            }
        }

        // 3. Resample every ~2 m.
        var cum: [Float] = [0]
        for i in 1...dense.count {
            cum.append(cum[i - 1] + (dense[i % dense.count] - dense[i - 1]).len)
        }
        let total = cum.last!
        let samples = max(100, Int((total / 2).rounded()))
        spacing = total / Float(samples)
        length = total
        count = samples

        var out: [V2] = []
        var outH: [Float] = []
        out.reserveCapacity(samples)
        var j = 0
        for k in 0..<samples {
            let target = Float(k) * spacing
            while j < dense.count - 1 && cum[j + 1] < target { j += 1 }
            let segL = cum[j + 1] - cum[j]
            let t = segL > 1e-5 ? (target - cum[j]) / segL : 0
            let a = dense[j], b = dense[(j + 1) % dense.count]
            out.append(a + (b - a) * t)
            outH.append(lerpf(denseH[j], denseH[(j + 1) % dense.count], t))
        }

        // 4. Light smoothing to iron out GPS wobble.
        for _ in 0..<3 {
            var sm = out
            for i in 0..<samples {
                var acc = V2(0, 0)
                for o in -2...2 { acc += out[(i + o + samples) % samples] }
                sm[i] = acc / 5
            }
            out = sm
        }
        pos = out
        height = outH

        computeFrames()
        computeLimits()
        computeSpeedProfile()
    }

    private static func catmullRom(_ p0: V2, _ p1: V2, _ p2: V2, _ p3: V2, _ u: Float) -> V2 {
        func knot(_ t: Float, _ a: V2, _ b: V2) -> Float { t + max((b - a).len.squareRoot(), 1e-3) }
        let t0: Float = 0
        let t1 = knot(t0, p0, p1), t2 = knot(t1, p1, p2), t3 = knot(t2, p2, p3)
        let t = t1 + (t2 - t1) * u
        let a1 = p0 * ((t1 - t) / (t1 - t0)) + p1 * ((t - t0) / (t1 - t0))
        let a2 = p1 * ((t2 - t) / (t2 - t1)) + p2 * ((t - t1) / (t2 - t1))
        let a3 = p2 * ((t3 - t) / (t3 - t2)) + p3 * ((t - t2) / (t3 - t2))
        let b1 = a1 * ((t2 - t) / (t2 - t0)) + a2 * ((t - t0) / (t2 - t0))
        let b2 = a2 * ((t3 - t) / (t3 - t1)) + a3 * ((t - t1) / (t3 - t1))
        return b1 * ((t2 - t) / (t2 - t1)) + b2 * ((t - t1) / (t2 - t1))
    }

    private func computeFrames() {
        let n = count
        tangent = (0..<n).map { i in (pos[(i + 1) % n] - pos[(i - 1 + n) % n]).norm }
        var k = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let a = tangent[(i - 2 + n) % n], b = tangent[(i + 2) % n]
            let d = wrapAngle(atan2(b.y, b.x) - atan2(a.y, a.x))
            k[i] = d / (4 * spacing)
        }
        // Average over ±12 m so curvature reflects the corner, not the noise.
        let w = 6
        curvature = (0..<n).map { i in
            var s: Float = 0
            for o in -w...w { s += k[(i + o + n) % n] }
            return s / Float(2 * w + 1)
        }
    }

    private func computeLimits() {
        let n = count
        let runoff: Float = info.isStreetCircuit ? 2.5 : 11
        var left = [Float](repeating: halfWidth + runoff, count: n)
        var right = left

        // Inside of tight corners: keep the wall from folding over itself.
        for i in 0..<n {
            let k = curvature[i]
            if abs(k) > 1e-4 {
                let inside = max(halfWidth + 0.8, 0.8 / abs(k))
                if k > 0 { right[i] = min(right[i], inside) } else { left[i] = min(left[i], inside) }
            }
        }

        // Other parts of the circuit running close by (hairpins, parallel straights).
        let cell: Float = 30
        var grid: [Int64: [Int]] = [:]
        func key(_ p: V2) -> Int64 {
            Int64(Int32(floor(p.x / cell))) << 32 | Int64(UInt32(bitPattern: Int32(floor(p.y / cell))))
        }
        for i in 0..<n { grid[key(pos[i]), default: []].append(i) }
        let reach = halfWidth * 2 + runoff * 2 + 4
        let skip = Int(150 / spacing)
        for i in 0..<n {
            let p = pos[i]
            let cx = Int32(floor(p.x / cell)), cy = Int32(floor(p.y / cell))
            for dx in -1...1 {
                for dy in -1...1 {
                    let kk = Int64(cx + Int32(dx)) << 32 | Int64(UInt32(bitPattern: cy + Int32(dy)))
                    guard let list = grid[kk] else { continue }
                    for j in list {
                        let gap = min(abs(i - j), n - abs(i - j))
                        if gap < skip { continue }
                        if abs(height[i] - height[j]) > 3 { continue }
                        let v = pos[j] - p
                        let dist = v.len
                        if dist > reach { continue }
                        let lateral = v.dot(tangent[i].right)
                        if abs(lateral) < dist * 0.6 { continue }
                        let lim = max(halfWidth + 0.6, dist * 0.5 - 0.3)
                        if lateral > 0 { right[i] = min(right[i], lim) } else { left[i] = min(left[i], lim) }
                    }
                }
            }
        }

        // Bridges: no run-off, just a parapet.
        for i in 0..<n where height[i] > 0.5 {
            left[i] = min(left[i], halfWidth + 1.2)
            right[i] = min(right[i], halfWidth + 1.2)
        }

        leftLimit = Track.smoothLimit(left)
        rightLimit = Track.smoothLimit(right)
    }

    private static func smoothLimit(_ a: [Float]) -> [Float] {
        let n = a.count
        var m = a
        for i in 0..<n {
            var v = a[i]
            for o in -4...4 { v = min(v, a[(i + o + n) % n]) }
            m[i] = v
        }
        var s = m
        for i in 0..<n {
            var acc: Float = 0
            for o in -3...3 { acc += m[(i + o + n) % n] }
            s[i] = min(acc / 7, a[i])
        }
        return s
    }

    private func computeSpeedProfile() {
        let n = count
        let g: Float = 9.81
        var v = (0..<n).map { i -> Float in
            min(120, (g / max(abs(curvature[i]), 1e-4)).squareRoot())
        }
        // Brake in time for each corner.
        let decel: Float = g * 0.85
        for _ in 0..<2 {
            for i in stride(from: n - 1, through: 0, by: -1) {
                let next = v[(i + 1) % n]
                v[i] = min(v[i], (next * next + 2 * decel * spacing).squareRoot())
            }
        }
        speedProfile = v
    }

    // MARK: Queries

    func wrapS(_ s: Float) -> Float {
        var x = s.truncatingRemainder(dividingBy: length)
        if x < 0 { x += length }
        return x
    }

    func index(atS s: Float) -> Int { min(count - 1, Int(wrapS(s) / spacing)) }

    private func interp(_ s: Float) -> (Int, Int, Float) {
        let w = wrapS(s) / spacing
        let i = min(count - 1, Int(w))
        return (i, (i + 1) % count, w - Float(i))
    }

    func center(atS s: Float) -> V2 {
        let (i, j, t) = interp(s)
        return pos[i] + (pos[j] - pos[i]) * t
    }

    func heightAt(s: Float) -> Float {
        let (i, j, t) = interp(s)
        return lerpf(height[i], height[j], t)
    }

    func tangentAt(s: Float) -> V2 {
        let (i, j, t) = interp(s)
        return (tangent[i] + (tangent[j] - tangent[i]) * t).norm
    }

    func point(atS s: Float, offset d: Float) -> V2 {
        center(atS: s) + tangentAt(s: s).right * d
    }

    func world(atS s: Float, offset d: Float, lift: Float = 0) -> V3 {
        let p = point(atS: s, offset: d)
        return V3(p.x, heightAt(s: s) + lift, p.y)
    }

    func targetSpeed(atS s: Float) -> Float {
        let (i, j, t) = interp(s)
        return lerpf(speedProfile[i], speedProfile[j], t)
    }

    func limits(atS s: Float) -> (left: Float, right: Float) {
        let (i, j, t) = interp(s)
        return (lerpf(leftLimit[i], leftLimit[j], t), lerpf(rightLimit[i], rightLimit[j], t))
    }

    /// Finds where a point is on the track: distance along it and offset from the centreline.
    /// `hint` is the last known sample index (or -1 to search everywhere).
    func locate(_ p: V2, hint: Int, heightHint: Float? = nil) -> (index: Int, s: Float, d: Float) {
        var best = 0
        var bestD = Float.greatestFiniteMagnitude
        if hint >= 0 {
            for o in -40...40 {
                let i = (hint + o + count) % count
                let d = (pos[i] - p).len
                if d < bestD { bestD = d; best = i }
            }
        } else {
            for i in 0..<count {
                var d = (pos[i] - p).len
                if let h = heightHint { d += abs(height[i] - h) * 4 }
                if d < bestD { bestD = d; best = i }
            }
        }
        let rel = p - pos[best]
        let along = rel.dot(tangent[best])
        let d = rel.dot(tangent[best].right)
        return (best, wrapS(Float(best) * spacing + along), d)
    }

    /// Outline points for maps, normalised to fit a unit square (y down).
    static func outline(_ info: TrackInfo) -> [CGPoint] {
        let xs = info.points.map { $0[0] }, ys = info.points.map { $0[1] }
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return [] }
        let size = max(maxX - minX, maxY - minY, 1)
        let ox = (size - (maxX - minX)) / 2, oy = (size - (maxY - minY)) / 2
        return info.points.map { CGPoint(x: ($0[0] - minX + ox) / size, y: ($0[1] - minY + oy) / size) }
    }
}
