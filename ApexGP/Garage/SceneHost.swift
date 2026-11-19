import SceneKit
import SpriteKit
import SwiftUI

/// Shows a SceneKit scene inside SwiftUI.
struct SceneHost: UIViewRepresentable {
    let scene: SCNScene
    var pointOfView: SCNNode?
    var delegate: SCNSceneRendererDelegate?
    var overlay: SKScene?

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.scene = scene
        v.pointOfView = pointOfView
        v.delegate = delegate
        v.overlaySKScene = overlay
        v.antialiasingMode = .multisampling4X
        v.preferredFramesPerSecond = 60
        v.isPlaying = true
        v.rendersContinuously = true
        v.backgroundColor = .black
        return v
    }

    func updateUIView(_ v: SCNView, context: Context) {
        if v.scene !== scene { v.scene = scene }
    }
}

/// A turntable in a dark studio for showing off the player's car.
final class GaragePreview: ObservableObject {
    let scene = SCNScene()
    let camera = SCNNode()
    private let turntable = SCNNode()
    private var carNode: CarNode?
    private var shown: CarConfig?

    init() {
        let floor = SCNFloor()
        floor.reflectivity = 0.12
        floor.reflectionFalloffEnd = 3
        let fm = Materials.plain(UIColor(hex: 0x15171B), roughness: 0.4)
        floor.materials = [fm]
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        let disc = SCNCylinder(radius: 3.6, height: 0.04)
        disc.materials = [Materials.plain(UIColor(hex: 0x24272D), roughness: 0.35, metalness: 0.3)]
        let dn = SCNNode(geometry: disc)
        dn.position.y = 0.0
        turntable.addChildNode(dn)
        scene.rootNode.addChildNode(turntable)

        let env = Textures.sky(top: UIColor(hex: 0x30343C), horizon: UIColor(hex: 0xC9CED6), ground: UIColor(hex: 0x1A1C20))
        scene.lightingEnvironment.contents = env
        scene.lightingEnvironment.intensity = 1.4
        scene.background.contents = UIColor(hex: 0x0B0C0F)

        for (pos, intensity) in [(SCNVector3(-4, 6, 4), 1400.0), (SCNVector3(5, 5, -3), 900.0), (SCNVector3(0, 7, -6), 700.0)] {
            let l = SCNNode()
            l.light = SCNLight()
            l.light?.type = .spot
            l.light?.intensity = CGFloat(intensity)
            l.light?.spotOuterAngle = 70
            l.light?.castsShadow = true
            l.light?.shadowRadius = 6
            l.light?.shadowColor = UIColor(white: 0, alpha: 0.6)
            l.position = pos
            l.look(at: SCNVector3(0, 0.5, 0))
            scene.rootNode.addChildNode(l)
        }
        let amb = SCNNode()
        amb.light = SCNLight()
        amb.light?.type = .ambient
        amb.light?.intensity = 250
        scene.rootNode.addChildNode(amb)

        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 32
        camera.position = SCNVector3(7.5, 2.4, 7.5)
        camera.look(at: SCNVector3(0, 0.55, 0))
        scene.rootNode.addChildNode(camera)

        turntable.runAction(.repeatForever(.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 24)))
    }

    func show(_ config: CarConfig) {
        guard config != shown else { return }
        shown = config
        carNode?.root.removeFromParentNode()
        let n = CarNode(config: config, withShadow: false)
        n.root.position.y = 0.02
        turntable.addChildNode(n.root)
        carNode = n
        // Frame longer vehicles a bit further away.
        let d = Float(config.model.lengthM) * 1.55 + 1
        camera.position = SCNVector3(d, 1.9 + Float(config.model.heightM) * 0.3, d)
        camera.look(at: SCNVector3(0, Float(config.model.heightM) * 0.42, 0))
    }
}
