import SceneKit
import UIKit

/// Builds the 3D world for a circuit: road, kerbs, walls, start gantry,
/// grandstands and scenery.
final class TrackScene {
    let node = SCNNode()
    /// The five start lights on the gantry, left to right.
    private(set) var startLights: [SCNMaterial] = []
    let isNight: Bool
    private let track: Track

    static let nightRaces: Set<String> = ["sg-2008", "us-2023", "bh-2002", "qa-2004", "sa-2021", "ae-2009"]

    init(track: Track, gridSlots: [(s: Float, d: Float)]) {
        self.track = track
        isNight = TrackScene.nightRaces.contains(track.info.id)
        // A stable seed per circuit, so the scenery is the same every race.
        var rng = SeededRandom(seed: UInt64(track.info.id.unicodeScalars.reduce(0) { $0 &* 31 &+ UInt64($1.value) }))

        buildGround()
        buildRoad()
        buildKerbs()
        buildWalls()
        buildStartLine(gridSlots: gridSlots)
        buildGantry()
        buildGrandstands()
        buildScenery(rng: &rng)
    }

    // MARK: Environment

    func applyEnvironment(to scene: SCNScene) {
        let sky: UIImage
        let fog: UIColor
        if isNight {
            sky = Textures.sky(top: UIColor(hex: 0x050816), horizon: UIColor(hex: 0x1C2440), ground: UIColor(hex: 0x10131C))
            fog = UIColor(hex: 0x141A2E)
        } else {
            sky = Textures.sky(top: UIColor(hex: 0x3D7DD8), horizon: UIColor(hex: 0xBFD8F0), ground: UIColor(hex: 0x8FA88A))
            fog = UIColor(hex: 0xBCD3E8)
        }
        scene.background.contents = sky
        scene.lightingEnvironment.contents = sky
        scene.lightingEnvironment.intensity = isNight ? 0.6 : 1.2
        scene.fogColor = fog
        scene.fogStartDistance = 350
        scene.fogEndDistance = 1500
        scene.fogDensityExponent = 1.2

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = isNight ? UIColor(hex: 0x8C96B8) : UIColor(hex: 0x8A8F99)
        ambient.light?.intensity = isNight ? 650 : 450
        scene.rootNode.addChildNode(ambient)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.color = isNight ? UIColor(hex: 0xE8ECFF) : UIColor(hex: 0xFFF4E0)
        sun.light?.intensity = isNight ? 700 : 1500
        sun.eulerAngles = SCNVector3(-0.9, 0.6, 0)
        scene.rootNode.addChildNode(sun)
    }

    // MARK: Pieces

    private func buildGround() {
        let xs = track.pos.map(\.x), zs = track.pos.map(\.y)
        let minX = xs.min()! - 900, maxX = xs.max()! + 900
        let minZ = zs.min()! - 900, maxZ = zs.max()! + 900
        let w = CGFloat(maxX - minX), h = CGFloat(maxZ - minZ)
        let plane = SCNPlane(width: w, height: h)
        let m = Materials.plain(isNight ? UIColor(white: 0.45, alpha: 1) : .white, roughness: 0.95)
        m.diffuse.contents = Textures.grass
        m.multiply.contents = isNight ? UIColor(white: 0.5, alpha: 1) : UIColor.white
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.contentsTransform = SCNMatrix4MakeScale(Float(w / 24), Float(h / 24), 1)
        plane.materials = [m]
        let n = SCNNode(geometry: plane)
        n.eulerAngles.x = -.pi / 2
        n.position = SCNVector3((minX + maxX) / 2, -0.02, (minZ + maxZ) / 2)
        node.addChildNode(n)
    }

    private func edgePoint(_ i: Int, _ d: Float, lift: Float) -> V3 {
        let p = track.pos[i] + track.tangent[i].right * d
        return V3(p.x, track.height[i] + lift, p.y)
    }

    /// A flat ribbon between two offsets, following the track.
    private func ribbon(from d0: (Int) -> Float, to d1: (Int) -> Float, lift: Float, vScale: Float,
                        include: (Int) -> Bool = { _ in true }, color: ((Int) -> UIColor)? = nil) -> MeshBuilder {
        var mb = MeshBuilder()
        let n = track.count
        var prev: (Int32, Int32)? = nil
        for k in 0...n {
            let i = k % n
            guard include(i) else { prev = nil; continue }
            let v = CGFloat(Float(k) * track.spacing / vScale)
            let col = color?(i)
            let a = mb.add(edgePoint(i, d0(i), lift: lift), uv: CGPoint(x: 0, y: v), color: col)
            let b = mb.add(edgePoint(i, d1(i), lift: lift), uv: CGPoint(x: 1, y: v), color: col)
            if let (pa, pb) = prev { mb.quad(pa, pb, a, b) }
            prev = (a, b)
        }
        return mb
    }

    private func buildRoad() {
        let hw = track.halfWidth
        let road = Materials.plain(.white, roughness: 0.85)
        road.diffuse.contents = Textures.asphalt
        road.diffuse.wrapS = .repeat
        road.diffuse.wrapT = .repeat
        road.diffuse.contentsTransform = SCNMatrix4MakeScale(3, 1, 1)
        road.isDoubleSided = true
        let mb = ribbon(from: { _ in -hw }, to: { _ in hw }, lift: 0.02, vScale: 6)
        node.addChildNode(SCNNode(geometry: mb.geometry(road)))

        let white = Materials.plain(UIColor(white: 0.95, alpha: 1), roughness: 0.7)
        white.isDoubleSided = true
        for side: Float in [-1, 1] {
            let inner: Float = (hw - 0.55) * side, outer: Float = (hw - 0.3) * side
            let lo = min(inner, outer), hi = max(inner, outer)
            let lines = ribbon(from: { _ in lo }, to: { _ in hi }, lift: 0.03, vScale: 6)
            node.addChildNode(SCNNode(geometry: lines.geometry(white)))
        }

        // Paved shoulders on bridges so there's no gap to the parapet.
        let deck = Materials.plain(UIColor(hex: 0x6E7176), roughness: 0.9)
        deck.isDoubleSided = true
        let left = ribbon(from: { -self.track.leftLimit[$0] }, to: { _ in -hw }, lift: 0.015, vScale: 6, include: { self.track.height[$0] > 0.2 })
        let right = ribbon(from: { _ in hw }, to: { self.track.rightLimit[$0] }, lift: 0.015, vScale: 6, include: { self.track.height[$0] > 0.2 })
        if !left.indices.isEmpty { node.addChildNode(SCNNode(geometry: left.geometry(deck))) }
        if !right.indices.isEmpty { node.addChildNode(SCNNode(geometry: right.geometry(deck))) }
    }

    private func buildKerbs() {
        let hw = track.halfWidth
        let red = UIColor(hex: 0xD32020), white = UIColor(white: 0.95, alpha: 1)
        let mat = Materials.plain(.white, roughness: 0.6)
        mat.isDoubleSided = true
        let isCorner: (Int) -> Bool = { abs(self.track.curvature[$0]) > 1 / 200 }
        let colour: (Int) -> UIColor = { i in (Int(Float(i) * self.track.spacing / 3) % 2 == 0) ? red : white }
        let r = ribbon(from: { _ in hw - 0.2 }, to: { _ in hw + 1.1 }, lift: 0.04, vScale: 6, include: isCorner, color: colour)
        let l = ribbon(from: { _ in -hw - 1.1 }, to: { _ in -hw + 0.2 }, lift: 0.04, vScale: 6, include: isCorner, color: colour)
        if !r.indices.isEmpty { node.addChildNode(SCNNode(geometry: r.geometry(mat))) }
        if !l.indices.isEmpty { node.addChildNode(SCNNode(geometry: l.geometry(mat))) }
    }

    private func buildWalls() {
        let street = track.info.isStreetCircuit
        let c1 = street ? UIColor(hex: 0xE8E8E8) : UIColor(hex: 0xF2F2F2)
        let c2 = street ? UIColor(hex: 0xD32F2F) : UIColor(hex: 0x2E6FD8)
        let mat = Materials.plain(.white, roughness: 0.5)
        mat.isDoubleSided = true
        var mb = MeshBuilder()
        let n = track.count
        for side: Float in [-1, 1] {
            var prev: (Int32, Int32)? = nil
            for k in 0...n {
                let i = k % n
                let d = side > 0 ? track.rightLimit[i] : -track.leftLimit[i]
                let p = track.pos[i] + track.tangent[i].right * d
                let col = (Int(Float(k) * track.spacing / 12) % 2 == 0) ? c1 : c2
                let normal = V3(-track.tangent[i].right.x * side, 0, -track.tangent[i].right.y * side)
                let top = mb.add(V3(p.x, track.height[i] + 1.0, p.y), normal: normal, color: col)
                let bottom = mb.add(V3(p.x, -0.05, p.y), normal: normal, color: col)
                if let (pt, pb) = prev { mb.quad(pt, pb, top, bottom) }
                prev = (top, bottom)
            }
        }
        node.addChildNode(SCNNode(geometry: mb.geometry(mat)))
    }

    private func buildStartLine(gridSlots: [(s: Float, d: Float)]) {
        let hw = track.halfWidth
        var mb = MeshBuilder()
        let s0: Float = -0.75, s1: Float = 0.75
        let reps = CGFloat(hw * 2 / 4)
        let a = track.world(atS: s0, offset: -hw, lift: 0.035), b = track.world(atS: s0, offset: hw, lift: 0.035)
        let c = track.world(atS: s1, offset: -hw, lift: 0.035), d = track.world(atS: s1, offset: hw, lift: 0.035)
        let ia = mb.add(a, uv: CGPoint(x: 0, y: 0)), ib = mb.add(b, uv: CGPoint(x: reps, y: 0))
        let ic = mb.add(c, uv: CGPoint(x: 0, y: 1)), id = mb.add(d, uv: CGPoint(x: reps, y: 1))
        mb.quad(ia, ib, ic, id)
        let m = Materials.plain(.white, roughness: 0.6)
        m.diffuse.contents = Textures.chequer
        m.diffuse.wrapS = .repeat
        m.isDoubleSided = true
        node.addChildNode(SCNNode(geometry: mb.geometry(m)))

        var slots = MeshBuilder()
        for slot in gridSlots {
            let front = slot.s + 2.6
            for (ds, dd0, dd1) in [(Float(0), Float(-1.2), Float(1.2)), (Float(-1.2), Float(-1.2), Float(-1.0)), (Float(-1.2), Float(1.0), Float(1.2))] {
                let sA = front + ds, sB = ds == 0 ? front + 0.25 : front
                let p0 = track.world(atS: min(sA, sB), offset: slot.d + dd0, lift: 0.035)
                let p1 = track.world(atS: min(sA, sB), offset: slot.d + dd1, lift: 0.035)
                let p2 = track.world(atS: max(sA, sB), offset: slot.d + dd0, lift: 0.035)
                let p3 = track.world(atS: max(sA, sB), offset: slot.d + dd1, lift: 0.035)
                let i0 = slots.add(p0), i1 = slots.add(p1), i2 = slots.add(p2), i3 = slots.add(p3)
                slots.quad(i0, i1, i2, i3)
            }
        }
        let sm = Materials.plain(UIColor(white: 0.95, alpha: 1), roughness: 0.7)
        sm.isDoubleSided = true
        if !slots.indices.isEmpty { node.addChildNode(SCNNode(geometry: slots.geometry(sm))) }
    }

    private func place(_ child: SCNNode, s: Float, d: Float, lift: Float = 0) {
        let p = track.world(atS: s, offset: d, lift: lift)
        let t = track.tangentAt(s: s)
        child.position = p.scn
        child.eulerAngles.y = -atan2(t.y, t.x)
        node.addChildNode(child)
    }

    private func buildGantry() {
        let lim = track.limits(atS: 0)
        let span = max(track.halfWidth + 1.5, min(lim.left, lim.right) - 0.3)
        let g = SCNNode()
        let steel = Materials.plain(UIColor(hex: 0x2B2F36), roughness: 0.4, metalness: 0.6)
        for side: Float in [-1, 1] {
            let post = SCNBox(width: 0.5, height: 7, length: 0.5, chamferRadius: 0)
            post.materials = [steel]
            let pn = SCNNode(geometry: post)
            pn.position = SCNVector3(0, 3.5, side * span)
            g.addChildNode(pn)
        }
        let beam = SCNBox(width: 1.0, height: 1.2, length: CGFloat(span * 2 + 0.5), chamferRadius: 0.05)
        beam.materials = [steel]
        let bn = SCNNode(geometry: beam)
        bn.position = SCNVector3(0, 6.6, 0)
        g.addChildNode(bn)
        for i in 0..<5 {
            let m = Materials.plain(UIColor(hex: 0x220000), roughness: 0.3, emission: .black)
            let lamp = SCNSphere(radius: 0.32)
            lamp.materials = [m]
            let ln = SCNNode(geometry: lamp)
            ln.position = SCNVector3(-0.55, 6.6, Float(i - 2) * 0.9)
            g.addChildNode(ln)
            startLights.append(m)
        }
        place(g, s: 1, d: 0)
    }

    /// 0…5 lights on; -1 for all off.
    func setStartLights(_ count: Int) {
        for (i, m) in startLights.enumerated() {
            let on = i < count
            m.emission.contents = on ? UIColor(red: 1, green: 0.05, blue: 0.05, alpha: 1) : UIColor.black
            m.diffuse.contents = on ? UIColor.red : UIColor(hex: 0x220000)
        }
    }

    private func buildGrandstands() {
        let crowd = Materials.plain(.white, roughness: 0.8)
        crowd.diffuse.contents = Textures.crowd
        crowd.diffuse.wrapS = .repeat
        crowd.diffuse.wrapT = .repeat
        crowd.diffuse.contentsTransform = SCNMatrix4MakeScale(6, 1, 1)
        let roofMat = Materials.plain(UIColor(hex: 0xEEEEEE), roughness: 0.4)
        let concrete = Materials.plain(UIColor(hex: 0x9EA2A8), roughness: 0.9)

        for k in 0..<3 {
            let s = Float(-210 + k * 75)
            let lim = track.limits(atS: s)
            let stand = SCNNode()
            for tier in 0..<5 {
                let box = SCNBox(width: 60, height: CGFloat(1.2 + Float(tier) * 1.4), length: 3, chamferRadius: 0)
                box.materials = [concrete, concrete, crowd, concrete, crowd, concrete]
                let bn = SCNNode(geometry: box)
                bn.position = SCNVector3(0, (1.2 + Float(tier) * 1.4) / 2, Float(tier) * 3)
                stand.addChildNode(bn)
            }
            let roof = SCNBox(width: 62, height: 0.4, length: 17, chamferRadius: 0)
            roof.materials = [roofMat]
            let rn = SCNNode(geometry: roof)
            rn.position = SCNVector3(0, 11, 6)
            stand.addChildNode(rn)
            place(stand, s: s, d: lim.right + 6)
        }

        // Pit building on the other side.
        let pit = SCNBox(width: 240, height: 9, length: 16, chamferRadius: 0)
        let windows = Materials.plain(.white, roughness: 0.3)
        windows.diffuse.contents = Textures.windows
        windows.diffuse.wrapS = .repeat
        windows.diffuse.contentsTransform = SCNMatrix4MakeScale(24, 1, 1)
        if isNight {
            windows.emission.contents = Textures.windowsLit
            windows.emission.wrapS = .repeat
            windows.emission.contentsTransform = SCNMatrix4MakeScale(24, 1, 1)
        }
        pit.materials = [windows, roofMat, windows, roofMat, roofMat, concrete]
        let pn = SCNNode(geometry: pit)
        pn.position.y = 4.5
        let holder = SCNNode()
        holder.addChildNode(pn)
        place(holder, s: -60, d: -(track.limits(atS: -60).left + 12))
    }

    private func buildScenery(rng: inout SeededRandom) {
        // Spatial lookup so nothing lands on the circuit.
        let cell: Float = 40
        var grid: [Int64: [Int]] = [:]
        func key(_ x: Int32, _ y: Int32) -> Int64 { Int64(x) << 32 | Int64(UInt32(bitPattern: y)) }
        for i in stride(from: 0, to: track.count, by: 2) {
            let p = track.pos[i]
            grid[key(Int32(floor(p.x / cell)), Int32(floor(p.y / cell))), default: []].append(i)
        }
        func clearance(_ p: V2) -> Float {
            let cx = Int32(floor(p.x / cell)), cy = Int32(floor(p.y / cell))
            var best = Float.greatestFiniteMagnitude
            for dx in -1...1 {
                for dy in -1...1 {
                    for i in grid[key(cx + Int32(dx), cy + Int32(dy))] ?? [] {
                        best = min(best, (track.pos[i] - p).len - max(track.leftLimit[i], track.rightLimit[i]))
                    }
                }
            }
            return best
        }

        let street = track.info.isStreetCircuit
        let container = SCNNode()
        let leafA = Materials.plain(UIColor(hex: isNight ? 0x173A1C : 0x2E6B2F), roughness: 0.9)
        let leafB = Materials.plain(UIColor(hex: isNight ? 0x1F4420 : 0x4C8A35), roughness: 0.9)
        let trunk = Materials.plain(UIColor(hex: 0x5A3E26), roughness: 0.9)
        let buildingMats: [SCNMaterial] = [0x8E99A6, 0xB8B2A7, 0x6F7C8C, 0xD0CCC4].map { hex in
            let m = Materials.plain(UIColor(hex: UInt32(hex)), roughness: 0.5)
            m.diffuse.contents = Textures.windows
            m.multiply.contents = UIColor(hex: UInt32(hex))
            m.diffuse.wrapS = .repeat
            m.diffuse.wrapT = .repeat
            m.diffuse.contentsTransform = SCNMatrix4MakeScale(4, 4, 1)
            if isNight {
                m.emission.contents = Textures.windowsLit
                m.emission.wrapS = .repeat
                m.emission.wrapT = .repeat
                m.emission.contentsTransform = SCNMatrix4MakeScale(4, 4, 1)
            }
            return m
        }

        let attempts = street ? 900 : 1400
        var placed = 0
        for _ in 0..<attempts {
            let i = Int(rng.next() % UInt64(track.count))
            let side: Float = rng.nextDouble() < 0.5 ? -1 : 1
            let lim = side > 0 ? track.rightLimit[i] : track.leftLimit[i]
            let wantBuilding = street ? rng.nextDouble() < 0.75 : rng.nextDouble() < 0.06
            let minGap: Float = wantBuilding ? 22 : 7
            let dist = lim + minGap + rng.range(0, wantBuilding ? 120 : 160)
            let p = track.pos[i] + track.tangent[i].right * (dist * side)
            if clearance(p) < minGap { continue }

            if wantBuilding {
                let w = CGFloat(rng.range(14, 34)), l = CGFloat(rng.range(14, 34)), h = CGFloat(rng.range(12, street ? 70 : 25))
                let box = SCNBox(width: w, height: h, length: l, chamferRadius: 0)
                box.materials = [buildingMats[Int(rng.next() % UInt64(buildingMats.count))]]
                let bn = SCNNode(geometry: box)
                bn.position = SCNVector3(p.x, Float(h) / 2, p.y)
                bn.eulerAngles.y = atan2(track.tangent[i].y, track.tangent[i].x)
                container.addChildNode(bn)
            } else {
                let h = rng.range(6, 14)
                let t = SCNCylinder(radius: 0.3, height: CGFloat(h * 0.35))
                t.materials = [trunk]
                let tn = SCNNode(geometry: t)
                tn.position = SCNVector3(p.x, h * 0.175, p.y)
                container.addChildNode(tn)
                if rng.nextDouble() < 0.5 {
                    let cone = SCNCone(topRadius: 0, bottomRadius: CGFloat(h * 0.3), height: CGFloat(h * 0.8))
                    cone.radialSegmentCount = 8
                    cone.materials = [leafA]
                    let cn = SCNNode(geometry: cone)
                    cn.position = SCNVector3(p.x, h * 0.6, p.y)
                    container.addChildNode(cn)
                } else {
                    let ball = SCNSphere(radius: CGFloat(h * 0.33))
                    ball.segmentCount = 8
                    ball.materials = [leafB]
                    let bn = SCNNode(geometry: ball)
                    bn.position = SCNVector3(p.x, h * 0.62, p.y)
                    container.addChildNode(bn)
                }
            }
            placed += 1
            if placed > (street ? 350 : 600) { break }
        }
        node.addChildNode(container.flattenedClone())
    }
}
