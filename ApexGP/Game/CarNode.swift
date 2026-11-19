import SceneKit
import UIKit

/// Side profile of each body style, as fractions: x 0 = rear … 1 = front,
/// y 0 = underside … 1 = roof.
private struct Profile {
    var lower: [CGPoint]
    /// Cabin outline: windscreen base, roof front, roof rear, rear glass base.
    var cabin: [CGPoint]
    var cabinWidth: CGFloat      // share of body width
    var wingX: CGFloat           // where a rear wing sits
    var wingY: CGFloat
    var lightY: CGFloat          // head/tail light height
    var tyreRadius: CGFloat
}

private func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

private func profile(for style: BodyStyle) -> Profile {
    switch style {
    case .coupe:
        return Profile(lower: [P(0, 0.12), P(0.02, 0), P(0.98, 0), P(1, 0.14), P(1, 0.36), P(0.96, 0.48), P(0.68, 0.58), P(0.25, 0.60), P(0.05, 0.58), P(0, 0.48)],
                       cabin: [P(0.68, 0.55), P(0.50, 1.0), P(0.33, 1.0), P(0.10, 0.57)],
                       cabinWidth: 0.78, wingX: 0.06, wingY: 0.58, lightY: 0.40, tyreRadius: 0.33)
    case .roadster:
        return Profile(lower: [P(0, 0.12), P(0.02, 0), P(0.98, 0), P(1, 0.16), P(1, 0.38), P(0.95, 0.52), P(0.64, 0.62), P(0.22, 0.63), P(0.04, 0.60), P(0, 0.50)],
                       cabin: [P(0.64, 0.60), P(0.50, 1.0), P(0.33, 1.0), P(0.22, 0.60)],
                       cabinWidth: 0.76, wingX: 0.06, wingY: 0.61, lightY: 0.42, tyreRadius: 0.31)
    case .rearEngine:
        return Profile(lower: [P(0, 0.14), P(0.02, 0), P(0.98, 0), P(1, 0.14), P(1, 0.32), P(0.95, 0.46), P(0.70, 0.56), P(0.22, 0.60), P(0.04, 0.54), P(0, 0.42)],
                       cabin: [P(0.70, 0.53), P(0.54, 1.0), P(0.42, 1.0), P(0.06, 0.55)],
                       cabinWidth: 0.78, wingX: 0.08, wingY: 0.58, lightY: 0.46, tyreRadius: 0.33)
    case .midEngine:
        return Profile(lower: [P(0, 0.14), P(0.02, 0), P(0.98, 0), P(1, 0.12), P(1, 0.28), P(0.94, 0.42), P(0.64, 0.56), P(0.35, 0.64), P(0.04, 0.64), P(0, 0.52)],
                       cabin: [P(0.66, 0.52), P(0.50, 1.0), P(0.38, 1.0), P(0.16, 0.62)],
                       cabinWidth: 0.74, wingX: 0.05, wingY: 0.64, lightY: 0.44, tyreRadius: 0.34)
    case .hatch:
        return Profile(lower: [P(0, 0.10), P(0.02, 0), P(0.98, 0), P(1, 0.12), P(1, 0.38), P(0.96, 0.50), P(0.74, 0.56), P(0.03, 0.58), P(0, 0.50)],
                       cabin: [P(0.75, 0.54), P(0.55, 1.0), P(0.08, 1.0), P(0.01, 0.56)],
                       cabinWidth: 0.82, wingX: 0.07, wingY: 1.0, lightY: 0.48, tyreRadius: 0.33)
    case .sedan:
        return Profile(lower: [P(0, 0.12), P(0.02, 0), P(0.98, 0), P(1, 0.12), P(1, 0.36), P(0.96, 0.48), P(0.72, 0.56), P(0.22, 0.58), P(0.02, 0.56), P(0, 0.44)],
                       cabin: [P(0.73, 0.54), P(0.56, 1.0), P(0.31, 1.0), P(0.14, 0.56)],
                       cabinWidth: 0.80, wingX: 0.04, wingY: 0.57, lightY: 0.46, tyreRadius: 0.33)
    case .suv:
        return Profile(lower: [P(0, 0.08), P(0.02, 0), P(0.98, 0), P(1, 0.10), P(1, 0.42), P(0.95, 0.52), P(0.78, 0.56), P(0.03, 0.58), P(0, 0.50)],
                       cabin: [P(0.79, 0.54), P(0.62, 1.0), P(0.06, 1.0), P(0.02, 0.56)],
                       cabinWidth: 0.84, wingX: 0.05, wingY: 1.0, lightY: 0.50, tyreRadius: 0.36)
    case .ute:
        return Profile(lower: [P(0, 0.06), P(0.02, 0), P(0.98, 0), P(1, 0.10), P(1, 0.46), P(0.96, 0.56), P(0.80, 0.58), P(0.02, 0.58), P(0, 0.50)],
                       cabin: [P(0.80, 0.56), P(0.66, 1.0), P(0.37, 1.0), P(0.35, 0.56)],
                       cabinWidth: 0.86, wingX: 0.30, wingY: 0.58, lightY: 0.50, tyreRadius: 0.40)
    }
}

/// A built car: the node tree plus handles for animating wheels and lights.
final class CarNode {
    let root = SCNNode()
    let body = SCNNode()          // rolls and pitches
    private(set) var spinners: [(node: SCNNode, sign: Float)] = []
    private(set) var steerers: [SCNNode] = []
    let brakeMaterial = Materials.plain(UIColor(hex: 0x5A0000), roughness: 0.3, emission: UIColor(hex: 0x400000))
    let tyreRadius: Float
    private var wheelAngle: Float = 0

    init(config: CarConfig, withShadow: Bool = true) {
        let model = config.model
        let prof = profile(for: model.style)
        let L = CGFloat(model.lengthM), W = CGFloat(model.widthM), H = CGFloat(model.heightM)
        let c = CGFloat(model.groundClearanceM)
        let wheelIn = CGFloat(config.wheelInches)
        let r = prof.tyreRadius + (wheelIn - 18) * 0.006
        tyreRadius = Float(r)

        func map(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - 0.5) * L, y: c + p.y * (H - c)) }

        root.addChildNode(body)
        let paint = Materials.paint(config.paint)
        let roofMat: SCNMaterial
        switch config.roof {
        case .body: roofMat = paint
        case .black: roofMat = Materials.blackTrim
        case .carbon: roofMat = Materials.carbon
        }

        // Lower body
        let bodyW = W - 0.06
        let lowerPts = prof.lower.map(map)
        let lower = SCNShape(path: CarNode.roundedPath(lowerPts, radius: 0.16), extrusionDepth: bodyW)
        lower.chamferRadius = 0.07
        lower.materials = [paint]
        body.addChildNode(SCNNode(geometry: lower))

        // Cabin (glass) with painted roof and pillars
        let cabW = bodyW * prof.cabinWidth
        let cab = prof.cabin.map(map)
        let cabinShape = SCNShape(path: CarNode.roundedPath(cab, radius: 0.08), extrusionDepth: cabW)
        cabinShape.chamferRadius = 0.06
        cabinShape.materials = [Materials.glass]
        body.addChildNode(SCNNode(geometry: cabinShape))

        let roofLen = cab[1].x - cab[2].x
        let roof = SCNBox(width: roofLen + 0.08, height: 0.035, length: cabW - 0.04, chamferRadius: 0.015)
        roof.materials = [roofMat]
        let roofNode = SCNNode(geometry: roof)
        roofNode.position = SCNVector3(Float((cab[1].x + cab[2].x) / 2), Float(cab[1].y) - 0.005, 0)
        body.addChildNode(roofNode)

        for z in [-cabW / 2, cabW / 2] {
            body.addChildNode(CarNode.bar(from: cab[0], to: cab[1], z: z, width: 0.07, material: roofMat))
            body.addChildNode(CarNode.bar(from: cab[2], to: cab[3], z: z, width: 0.10, material: roofMat))
            let mid = CGPoint(x: (cab[1].x + cab[2].x) / 2 + roofLen * 0.05, y: cab[1].y)
            let midBase = CGPoint(x: mid.x + 0.12, y: cab[0].y)
            body.addChildNode(CarNode.bar(from: midBase, to: mid, z: z, width: 0.06, material: Materials.blackTrim))
        }

        // Stripes
        let stripeMat = Materials.plain(UIColor(config.stripeColor.rgb), roughness: 0.3)
        stripeMat.clearCoat.contents = 1.0
        func stripeSlice(z: CGFloat, width: CGFloat) {
            let s = SCNShape(path: CarNode.roundedPath(lowerPts, radius: 0.16), extrusionDepth: width)
            s.chamferRadius = 0
            s.materials = [stripeMat]
            let n = SCNNode(geometry: s)
            n.scale = SCNVector3(1.004, 1.012, 1)
            n.position = SCNVector3(0, -0.004, Float(z))
            body.addChildNode(n)
            let rs = SCNBox(width: roofLen + 0.06, height: 0.01, length: width, chamferRadius: 0)
            rs.materials = [stripeMat]
            let rn = SCNNode(geometry: rs)
            rn.position = SCNVector3(roofNode.position.x, roofNode.position.y + 0.02, Float(z))
            body.addChildNode(rn)
        }
        switch config.stripes {
        case .none: break
        case .racing:
            stripeSlice(z: -0.17, width: 0.2)
            stripeSlice(z: 0.17, width: 0.2)
        case .centre:
            stripeSlice(z: 0, width: 0.34)
        case .side:
            for side: CGFloat in [-1, 1] {
                let b = SCNBox(width: L * 0.72, height: 0.07, length: 0.01, chamferRadius: 0)
                b.materials = [stripeMat]
                let n = SCNNode(geometry: b)
                n.position = SCNVector3(0, Float(c + 0.30 * (H - c)), Float(side * (bodyW / 2 + 0.006)))
                body.addChildNode(n)
            }
        }

        // Lights, grille, mirrors, exhausts
        let lightY = Float(c + prof.lightY * (H - c))
        let headMat = Materials.plain(.white, roughness: 0.1, emission: UIColor(white: 0.9, alpha: 1))
        for side: Float in [-1, 1] {
            let head = SCNBox(width: 0.3, height: 0.08, length: 0.36, chamferRadius: 0.03)
            head.materials = [headMat]
            let hn = SCNNode(geometry: head)
            hn.position = SCNVector3(Float(L / 2) - 0.14, lightY - 0.02, side * Float(W / 2 - 0.32))
            body.addChildNode(hn)

            let tail = SCNBox(width: 0.06, height: 0.07, length: 0.42, chamferRadius: 0.02)
            tail.materials = [brakeMaterial]
            let tn = SCNNode(geometry: tail)
            tn.position = SCNVector3(-Float(L / 2) + 0.03, lightY, side * Float(W / 2 - 0.3))
            body.addChildNode(tn)

            let mirror = SCNBox(width: 0.1, height: 0.09, length: 0.16, chamferRadius: 0.03)
            mirror.materials = [config.roof == .body ? paint : roofMat]
            let mn = SCNNode(geometry: mirror)
            mn.position = SCNVector3(Float(cab[0].x) - 0.12, Float(cab[0].y) + 0.08, side * Float(cabW / 2 + 0.1))
            body.addChildNode(mn)

            let ex = SCNCylinder(radius: 0.045, height: 0.12)
            ex.materials = [Materials.plain(UIColor(hex: 0x555555), roughness: 0.3, metalness: 1)]
            let en = SCNNode(geometry: ex)
            en.eulerAngles.z = .pi / 2
            en.position = SCNVector3(-Float(L / 2) + 0.02, Float(c) + 0.08, side * 0.3)
            body.addChildNode(en)
        }
        let grille = SCNBox(width: 0.05, height: 0.14, length: W * 0.5, chamferRadius: 0.02)
        grille.materials = [Materials.blackTrim]
        let gn = SCNNode(geometry: grille)
        gn.position = SCNVector3(Float(L / 2) - 0.01, Float(c) + 0.12, 0)
        body.addChildNode(gn)

        // Wing
        let wingBaseX = Float(map(CGPoint(x: prof.wingX, y: 0)).x)
        let wingBaseY = Float(c + prof.wingY * (H - c))
        let wingMat = config.roof == .carbon ? Materials.carbon : (config.roof == .black ? Materials.blackTrim : paint)
        switch config.effectiveWing {
        case .gt:
            let lift: Float = model.style == .hatch || model.style == .suv ? 0.05 : 0.28
            let plane = SCNBox(width: 0.32, height: 0.03, length: W * 0.86, chamferRadius: 0.012)
            plane.materials = [wingMat]
            let pn = SCNNode(geometry: plane)
            pn.position = SCNVector3(wingBaseX, wingBaseY + lift, 0)
            pn.eulerAngles.z = 0.08
            body.addChildNode(pn)
            if lift > 0.1 {
                for side: Float in [-1, 1] {
                    let post = SCNBox(width: 0.1, height: CGFloat(lift), length: 0.03, chamferRadius: 0)
                    post.materials = [Materials.blackTrim]
                    let n = SCNNode(geometry: post)
                    n.position = SCNVector3(wingBaseX + 0.04, wingBaseY + lift / 2, side * Float(W * 0.25))
                    body.addChildNode(n)
                }
                for side: Float in [-1, 1] {
                    let plate = SCNBox(width: 0.36, height: 0.16, length: 0.015, chamferRadius: 0.01)
                    plate.materials = [wingMat]
                    let n = SCNNode(geometry: plate)
                    n.position = SCNVector3(wingBaseX, wingBaseY + lift + 0.02, side * Float(W * 0.43))
                    body.addChildNode(n)
                }
            }
        case .lip:
            let lip = SCNBox(width: 0.2, height: 0.05, length: W * 0.8, chamferRadius: 0.02)
            lip.materials = [wingMat]
            let n = SCNNode(geometry: lip)
            n.position = SCNVector3(wingBaseX - 0.05, wingBaseY + 0.02, 0)
            n.eulerAngles.z = 0.25
            body.addChildNode(n)
        case .none, .factory:
            break
        }
        if model.style == .ute {
            // Sports bar behind the cab.
            let barMat = Materials.blackTrim
            let bx = Float(cab[3].x) - 0.25
            for side: Float in [-1, 1] {
                let post = SCNCylinder(radius: 0.035, height: 0.45)
                post.materials = [barMat]
                let n = SCNNode(geometry: post)
                n.position = SCNVector3(bx, Float(cab[3].y) + 0.22, side * Float(W * 0.4))
                body.addChildNode(n)
            }
            let top = SCNCylinder(radius: 0.035, height: W * 0.8)
            top.materials = [barMat]
            let tn = SCNNode(geometry: top)
            tn.eulerAngles.x = .pi / 2
            tn.position = SCNVector3(bx, Float(cab[3].y) + 0.45, 0)
            body.addChildNode(tn)
        }

        // Racing number on the doors
        let doorX = Float((cab[0].x + cab[3].x) / 2)
        let doorY = Float(c + 0.32 * (H - c))
        for side: Float in [-1, 1] {
            let holder = SCNNode()
            holder.position = SCNVector3(doorX, doorY, side * Float(bodyW / 2 + 0.035))
            if side < 0 { holder.eulerAngles.y = .pi }
            let disc = SCNCylinder(radius: 0.2, height: 0.008)
            disc.materials = [Materials.plain(.white, roughness: 0.4)]
            let dn = SCNNode(geometry: disc)
            dn.eulerAngles.x = .pi / 2
            holder.addChildNode(dn)
            let text = SCNText(string: "\(config.number)", extrusionDepth: 0.4)
            text.font = UIFont.systemFont(ofSize: 10, weight: .heavy)
            text.flatness = 0.15
            text.materials = [Materials.plain(.black, roughness: 0.4)]
            let tn = SCNNode(geometry: text)
            let (mn, mx) = text.boundingBox
            let scale: Float = 0.026
            tn.scale = SCNVector3(scale, scale, scale)
            tn.position = SCNVector3(-(mn.x + mx.x) / 2 * scale, -(mn.y + mx.y) / 2 * scale, 0.006)
            holder.addChildNode(tn)
            body.addChildNode(holder)
        }

        // Wheels
        let tyreW: CGFloat = model.style == .ute ? 0.28 : 0.26
        let wheelZ = Float(W / 2 - tyreW / 2 - 0.01)
        let wb = Float(model.wheelbaseM)
        let rimR = min(r - 0.06, wheelIn * 0.0254 / 2 + 0.01)
        let wheelMat = Materials.wheel(config.wheelFinish, body: config.paint)
        let caliperMat = Materials.plain(UIColor(config.caliper.rgb), roughness: 0.35)
        for (i, x) in [wb / 2, -wb / 2].enumerated() {
            for side: Float in [-1, 1] {
                let mount = SCNNode()
                mount.position = SCNVector3(x, Float(r), side * wheelZ)
                root.addChildNode(mount)
                let flip = SCNNode()
                if side < 0 { flip.eulerAngles.y = .pi }
                mount.addChildNode(flip)
                let spin = CarNode.wheel(style: config.wheelStyle, tyreR: r, rimR: rimR, tyreW: tyreW, rimMat: wheelMat)
                flip.addChildNode(spin)
                let cal = SCNBox(width: 0.14, height: 0.08, length: 0.05, chamferRadius: 0.015)
                cal.materials = [caliperMat]
                let cn = SCNNode(geometry: cal)
                let a: Float = 2.4
                let cr = Float(rimR) * 0.62
                cn.position = SCNVector3(cos(a) * cr, sin(a) * cr, Float(tyreW / 2) - 0.07)
                cn.eulerAngles.z = a - .pi / 2
                flip.addChildNode(cn)
                spinners.append((spin, side > 0 ? -1 : 1))
                if i == 0 { steerers.append(mount) }

                // Dark wheel arch behind the tyre.
                let arch = SCNCylinder(radius: r + 0.05, height: 0.01)
                arch.materials = [Materials.rubber]
                let an = SCNNode(geometry: arch)
                an.eulerAngles.x = .pi / 2
                an.position = SCNVector3(x, Float(r), side * Float(bodyW / 2 + 0.002))
                body.addChildNode(an)
            }
        }

        if withShadow {
            let plane = SCNPlane(width: L * 1.15, height: W * 1.25)
            let m = SCNMaterial()
            m.diffuse.contents = Textures.shadow
            m.lightingModel = .constant
            m.writesToDepthBuffer = false
            m.blendMode = .alpha
            plane.materials = [m]
            let sn = SCNNode(geometry: plane)
            sn.eulerAngles.x = -.pi / 2
            sn.position = SCNVector3(0, 0.03, 0)
            sn.renderingOrder = -1
            root.addChildNode(sn)
        }
    }

    // MARK: Animation

    func update(speed: Float, steer: Float, dt: Float, roll: Float, pitch: Float, braking: Bool) {
        wheelAngle = (wheelAngle + speed * dt / tyreRadius).truncatingRemainder(dividingBy: 2 * .pi)
        for s in spinners {
            s.node.eulerAngles.z = s.sign * wheelAngle
        }
        for st in steerers {
            st.eulerAngles.y = -steer * 0.45
        }
        body.eulerAngles.x = roll
        body.eulerAngles.z = pitch
        brakeMaterial.emission.contents = braking ? UIColor(red: 1, green: 0.05, blue: 0.05, alpha: 1) : UIColor(hex: 0x400000)
    }

    // MARK: Pieces

    /// Polygon with corners rounded off, as a closed path.
    static func roundedPath(_ pts: [CGPoint], radius: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let n = pts.count
        func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint { CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t) }
        func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(b.x - a.x, b.y - a.y) }
        for i in 0..<n {
            let prev = pts[(i - 1 + n) % n], cur = pts[i], next = pts[(i + 1) % n]
            let r1 = min(radius, dist(prev, cur) * 0.45), r2 = min(radius, dist(cur, next) * 0.45)
            let a = lerp(cur, prev, r1 / max(dist(prev, cur), 1e-4))
            let b = lerp(cur, next, r2 / max(dist(cur, next), 1e-4))
            if i == 0 { path.move(to: a) } else { path.addLine(to: a) }
            path.addQuadCurve(to: b, controlPoint: cur)
        }
        path.close()
        path.flatness = 0.01
        return path
    }

    static func bar(from a: CGPoint, to b: CGPoint, z: CGFloat, width: CGFloat, material: SCNMaterial) -> SCNNode {
        let len = hypot(b.x - a.x, b.y - a.y)
        let box = SCNBox(width: len, height: width, length: 0.05, chamferRadius: 0.01)
        box.materials = [material]
        let n = SCNNode(geometry: box)
        n.position = SCNVector3(Float((a.x + b.x) / 2), Float((a.y + b.y) / 2), Float(z))
        n.eulerAngles.z = Float(atan2(b.y - a.y, b.x - a.x))
        return n
    }

    static func wheel(style: WheelStyle, tyreR: CGFloat, rimR: CGFloat, tyreW: CGFloat, rimMat: SCNMaterial) -> SCNNode {
        let spin = SCNNode()
        let tyre = SCNCylinder(radius: tyreR, height: tyreW)
        tyre.radialSegmentCount = 32
        tyre.materials = [Materials.rubber]
        let tn = SCNNode(geometry: tyre)
        tn.eulerAngles.x = .pi / 2
        spin.addChildNode(tn)

        let face = Float(tyreW / 2)
        let barrel = SCNCylinder(radius: rimR, height: 0.01)
        barrel.materials = [Materials.plain(UIColor(hex: 0x202224), roughness: 0.6, metalness: 0.5)]
        let bn = SCNNode(geometry: barrel)
        bn.eulerAngles.x = .pi / 2
        bn.position.z = face - 0.03
        spin.addChildNode(bn)

        let lip = SCNTube(innerRadius: rimR - 0.025, outerRadius: rimR, height: 0.04)
        lip.radialSegmentCount = 32
        lip.materials = [rimMat]
        let ln = SCNNode(geometry: lip)
        ln.eulerAngles.x = .pi / 2
        ln.position.z = face - 0.005
        spin.addChildNode(ln)

        func spoke(angle: Float, width: CGFloat, twist: Float = 0, inner: CGFloat = 0.06) {
            let len = rimR - 0.02 - inner
            let box = SCNBox(width: len, height: width, length: 0.03, chamferRadius: min(width / 2, 0.01))
            box.materials = [rimMat]
            let n = SCNNode(geometry: box)
            let mid = Float(inner + len / 2)
            n.position = SCNVector3(cos(angle) * mid, sin(angle) * mid, face - 0.005)
            n.eulerAngles.z = angle + twist
            spin.addChildNode(n)
        }

        switch style {
        case .fiveSpoke:
            for i in 0..<5 { spoke(angle: Float(i) * 2 * .pi / 5, width: rimR * 0.32) }
        case .tenSpoke:
            for i in 0..<10 { spoke(angle: Float(i) * 2 * .pi / 10, width: rimR * 0.13) }
        case .yspoke:
            for i in 0..<5 {
                let a = Float(i) * 2 * .pi / 5
                spoke(angle: a, width: rimR * 0.18)
                spoke(angle: a + 0.22, width: rimR * 0.1, twist: -0.12, inner: rimR * 0.45)
                spoke(angle: a - 0.22, width: rimR * 0.1, twist: 0.12, inner: rimR * 0.45)
            }
        case .mesh:
            for i in 0..<16 { spoke(angle: Float(i) * 2 * .pi / 16, width: rimR * 0.07) }
            let ring = SCNTube(innerRadius: rimR * 0.5, outerRadius: rimR * 0.56, height: 0.03)
            ring.materials = [rimMat]
            let rn = SCNNode(geometry: ring)
            rn.eulerAngles.x = .pi / 2
            rn.position.z = face
            spin.addChildNode(rn)
        case .turbine:
            for i in 0..<12 { spoke(angle: Float(i) * 2 * .pi / 12, width: rimR * 0.12, twist: 0.45) }
        case .rally:
            let dish = SCNCylinder(radius: rimR - 0.01, height: 0.02)
            dish.materials = [rimMat]
            let dn = SCNNode(geometry: dish)
            dn.eulerAngles.x = .pi / 2
            dn.position.z = face - 0.01
            spin.addChildNode(dn)
            for i in 0..<6 {
                let a = Float(i) * 2 * .pi / 6
                let hole = SCNCylinder(radius: rimR * 0.16, height: 0.024)
                hole.materials = [Materials.plain(UIColor(hex: 0x181818))]
                let hn = SCNNode(geometry: hole)
                hn.eulerAngles.x = .pi / 2
                let rr = Float(rimR) * 0.6
                hn.position = SCNVector3(cos(a) * rr, sin(a) * rr, face - 0.008)
                spin.addChildNode(hn)
            }
        }
        let cap = SCNCylinder(radius: 0.055, height: 0.04)
        cap.materials = [rimMat]
        let capN = SCNNode(geometry: cap)
        capN.eulerAngles.x = .pi / 2
        capN.position.z = face
        spin.addChildNode(capN)
        return spin
    }
}
