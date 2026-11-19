import SceneKit
import UIKit

extension V3 {
    var scn: SCNVector3 { SCNVector3(x, y, z) }
}

extension UIColor {
    convenience init(_ rgb: RGB, alpha: CGFloat = 1) {
        self.init(red: CGFloat(rgb.r), green: CGFloat(rgb.g), blue: CGFloat(rgb.b), alpha: alpha)
    }
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(RGB(hex), alpha: alpha)
    }
}

/// Collects triangles and turns them into an SCNGeometry.
struct MeshBuilder {
    var vertices: [SCNVector3] = []
    var normals: [SCNVector3] = []
    var uvs: [CGPoint] = []
    var colors: [Float] = []
    var indices: [Int32] = []
    var useColors = false

    @discardableResult
    mutating func add(_ p: V3, normal: V3 = V3(0, 1, 0), uv: CGPoint = .zero, color: UIColor? = nil) -> Int32 {
        vertices.append(p.scn)
        normals.append(normal.scn)
        uvs.append(uv)
        if let c = color {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            c.getRed(&r, green: &g, blue: &b, alpha: &a)
            colors += [Float(r), Float(g), Float(b)]
            useColors = true
        } else {
            colors += [1, 1, 1]
        }
        return Int32(vertices.count - 1)
    }

    mutating func tri(_ a: Int32, _ b: Int32, _ c: Int32) {
        indices += [a, b, c]
    }

    /// Quad a-b (one edge, a on the left) to c-d (next edge, c on the left).
    mutating func quad(_ a: Int32, _ b: Int32, _ c: Int32, _ d: Int32) {
        indices += [a, b, c, b, d, c]
    }

    func geometry(_ material: SCNMaterial) -> SCNGeometry {
        var sources = [
            SCNGeometrySource(vertices: vertices),
            SCNGeometrySource(normals: normals),
            SCNGeometrySource(textureCoordinates: uvs),
        ]
        if useColors {
            let data = colors.withUnsafeBufferPointer { Data(buffer: $0) }
            sources.append(SCNGeometrySource(data: data, semantic: .color, vectorCount: vertices.count,
                                             usesFloatComponents: true, componentsPerVector: 3,
                                             bytesPerComponent: MemoryLayout<Float>.size, dataOffset: 0,
                                             dataStride: MemoryLayout<Float>.size * 3))
        }
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let g = SCNGeometry(sources: sources, elements: [element])
        g.materials = [material]
        return g
    }
}

enum Materials {
    static func plain(_ color: UIColor, roughness: CGFloat = 0.6, metalness: CGFloat = 0, emission: UIColor? = nil) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = color
        m.roughness.contents = roughness
        m.metalness.contents = metalness
        if let e = emission { m.emission.contents = e }
        return m
    }

    static func paint(_ paint: Paint) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = UIColor(paint.color)
        switch paint.finish {
        case .solid:
            m.metalness.contents = 0.05; m.roughness.contents = 0.28
            m.clearCoat.contents = 1.0; m.clearCoatRoughness.contents = 0.05
        case .metallic:
            m.metalness.contents = 0.55; m.roughness.contents = 0.32
            m.clearCoat.contents = 1.0; m.clearCoatRoughness.contents = 0.05
        case .pearl:
            m.metalness.contents = 0.35; m.roughness.contents = 0.22
            m.clearCoat.contents = 1.0; m.clearCoatRoughness.contents = 0.03
        case .matte:
            m.metalness.contents = 0.1; m.roughness.contents = 0.7
        case .chrome:
            m.metalness.contents = 1.0; m.roughness.contents = 0.08
        }
        return m
    }

    static func wheel(_ finish: WheelFinish, body: Paint) -> SCNMaterial {
        switch finish {
        case .silver: return plain(UIColor(hex: 0xC3C7CC), roughness: 0.25, metalness: 0.9)
        case .gloss: return plain(UIColor(hex: 0x141414), roughness: 0.15, metalness: 0.3)
        case .gunmetal: return plain(UIColor(hex: 0x3E4248), roughness: 0.3, metalness: 0.85)
        case .bronze: return plain(UIColor(hex: 0x8C6A3F), roughness: 0.3, metalness: 0.9)
        case .gold: return plain(UIColor(hex: 0xC9A23A), roughness: 0.25, metalness: 1.0)
        case .chrome: return plain(UIColor(hex: 0xEDEFF2), roughness: 0.04, metalness: 1.0)
        case .white: return plain(UIColor(hex: 0xF0F0F0), roughness: 0.3)
        case .body: return paint(body)
        }
    }

    static let glass: SCNMaterial = plain(UIColor(hex: 0x0B1220), roughness: 0.06, metalness: 0.85)
    static let rubber: SCNMaterial = plain(UIColor(hex: 0x1B1B1B), roughness: 0.9)
    static let blackTrim: SCNMaterial = plain(UIColor(hex: 0x111111), roughness: 0.45)
    static let carbon: SCNMaterial = {
        let m = plain(UIColor(hex: 0x1E1F22), roughness: 0.25, metalness: 0.4)
        m.diffuse.contents = Textures.carbon
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.contentsTransform = SCNMatrix4MakeScale(8, 8, 1)
        return m
    }()
}

/// Small textures drawn in code, so the game ships with no image files.
enum Textures {
    private static func draw(_ w: Int, _ h: Int, _ body: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: format).image { ctx in
            body(ctx.cgContext)
        }
    }

    private static func noise(_ w: Int, _ h: Int, cell: Int, base: RGB, spread: Double, seed: UInt64) -> UIImage {
        var rng = SeededRandom(seed: seed)
        return draw(w, h) { c in
            for y in stride(from: 0, to: h, by: cell) {
                for x in stride(from: 0, to: w, by: cell) {
                    let k = 1 + (rng.nextDouble() - 0.5) * spread
                    c.setFillColor(UIColor(red: CGFloat(base.r * k), green: CGFloat(base.g * k), blue: CGFloat(base.b * k), alpha: 1).cgColor)
                    c.fill(CGRect(x: x, y: y, width: cell, height: cell))
                }
            }
        }
    }

    static let asphalt = noise(128, 128, cell: 2, base: RGB(0x3A3C40), spread: 0.35, seed: 1)
    static let grass: UIImage = {
        var rng = SeededRandom(seed: 2)
        return draw(128, 128) { c in
            for y in stride(from: 0, to: 128, by: 4) {
                for x in stride(from: 0, to: 128, by: 4) {
                    let stripe = (x / 64) % 2 == 0 ? 1.0 : 0.88
                    let k = stripe * (1 + (rng.nextDouble() - 0.5) * 0.18)
                    c.setFillColor(UIColor(red: 0.27 * k, green: 0.52 * k, blue: 0.20 * k, alpha: 1).cgColor)
                    c.fill(CGRect(x: x, y: y, width: 4, height: 4))
                }
            }
        }
    }()
    static let sand = noise(64, 64, cell: 2, base: RGB(0xC9B48A), spread: 0.25, seed: 3)
    static let carbon: UIImage = draw(16, 16) { c in
        for y in 0..<4 {
            for x in 0..<4 {
                let light = (x + y) % 2 == 0
                c.setFillColor(UIColor(white: light ? 0.2 : 0.1, alpha: 1).cgColor)
                c.fill(CGRect(x: x * 4, y: y * 4, width: 4, height: 4))
            }
        }
    }
    static let chequer: UIImage = draw(64, 16) { c in
        for y in 0..<2 {
            for x in 0..<8 {
                c.setFillColor(((x + y) % 2 == 0 ? UIColor.white : UIColor.black).cgColor)
                c.fill(CGRect(x: x * 8, y: y * 8, width: 8, height: 8))
            }
        }
    }
    static let shadow: UIImage = draw(64, 64) { c in
        let colors = [UIColor(white: 0, alpha: 0.75).cgColor, UIColor(white: 0, alpha: 0).cgColor] as CFArray
        let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
        c.drawRadialGradient(grad, startCenter: CGPoint(x: 32, y: 32), startRadius: 6,
                             endCenter: CGPoint(x: 32, y: 32), endRadius: 32, options: [])
    }
    static let crowd: UIImage = {
        var rng = SeededRandom(seed: 4)
        let palette: [UInt32] = [0xD32F2F, 0xFFFFFF, 0x1976D2, 0xFBC02D, 0x388E3C, 0xF57C00, 0x222222, 0xE0C097]
        return draw(128, 32) { c in
            c.setFillColor(UIColor(hex: 0x30343A).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: 128, height: 32))
            for y in stride(from: 1, to: 32, by: 4) {
                for x in stride(from: 1, to: 128, by: 3) where rng.nextDouble() < 0.85 {
                    c.setFillColor(UIColor(hex: palette[Int(rng.next() % UInt64(palette.count))]).cgColor)
                    c.fill(CGRect(x: x, y: y, width: 2, height: 3))
                }
            }
        }
    }()
    static let windows: UIImage = {
        var rng = SeededRandom(seed: 5)
        return draw(32, 64) { c in
            c.setFillColor(UIColor(hex: 0x6B7078).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: 32, height: 64))
            for y in stride(from: 2, to: 64, by: 6) {
                for x in stride(from: 2, to: 32, by: 6) {
                    let lit = rng.nextDouble()
                    c.setFillColor(UIColor(red: 0.25 + lit * 0.2, green: 0.32 + lit * 0.2, blue: 0.42 + lit * 0.2, alpha: 1).cgColor)
                    c.fill(CGRect(x: x, y: y, width: 4, height: 4))
                }
            }
        }
    }()
    static let windowsLit: UIImage = {
        var rng = SeededRandom(seed: 6)
        return draw(32, 64) { c in
            c.setFillColor(UIColor.black.cgColor)
            c.fill(CGRect(x: 0, y: 0, width: 32, height: 64))
            for y in stride(from: 2, to: 64, by: 6) {
                for x in stride(from: 2, to: 32, by: 6) where rng.nextDouble() < 0.45 {
                    c.setFillColor(UIColor(red: 1, green: 0.85, blue: 0.55, alpha: 1).cgColor)
                    c.fill(CGRect(x: x, y: y, width: 4, height: 4))
                }
            }
        }
    }()

    static func sky(top: UIColor, horizon: UIColor, ground: UIColor) -> UIImage {
        draw(4, 256) { c in
            let colors = [top.cgColor, horizon.cgColor, ground.cgColor] as CFArray
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 1])!
            c.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: 256), options: [])
        }
    }
}

/// Repeatable random numbers, so a track always gets the same trees.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
    mutating func nextDouble() -> Double { Double(next() % 1_000_000) / 1_000_000 }
    mutating func range(_ lo: Float, _ hi: Float) -> Float { lo + Float(nextDouble()) * (hi - lo) }
}
