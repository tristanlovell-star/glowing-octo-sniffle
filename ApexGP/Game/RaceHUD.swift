import SpriteKit
import UIKit

/// The 2D overlay drawn over the race: position, laps, times, speed,
/// a mini-map, the timing tower and big messages.
final class RaceHUD: SKScene {
    private let font = "AvenirNext-HeavyItalic"
    private let bodyFont = "AvenirNext-DemiBold"

    private let posLabel = SKLabelNode()
    private let posTotal = SKLabelNode()
    private let lapLabel = SKLabelNode()
    private let timeLabel = SKLabelNode()
    private let bestLabel = SKLabelNode()
    private let speedLabel = SKLabelNode()
    private let unitLabel = SKLabelNode()
    private let gearLabel = SKLabelNode()
    private let message = SKLabelNode()
    private let subMessage = SKLabelNode()
    private let hint = SKLabelNode()
    private let map = SKNode()
    private var mapDots: [SKShapeNode] = []
    private var lights: [SKShapeNode] = []
    private let lightsPanel = SKNode()
    private let tower = SKNode()
    private var towerRows: [(bg: SKShapeNode, pos: SKLabelNode, name: SKLabelNode)] = []

    private var mapTransform: (V2) -> CGPoint = { _ in .zero }
    private var messageUntil: TimeInterval = 0
    private var built = false
    private let track: Track
    private let carCount: Int
    private let playerIndex: Int
    private let carColors: [UIColor]

    init(size: CGSize, track: Track, carColors: [UIColor], playerIndex: Int) {
        self.track = track
        self.carCount = carColors.count
        self.playerIndex = playerIndex
        self.carColors = carColors
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    private func label(_ l: SKLabelNode, size: CGFloat, font: String? = nil, align: SKLabelHorizontalAlignmentMode = .left) {
        l.fontName = font ?? self.font
        l.fontSize = size
        l.fontColor = .white
        l.horizontalAlignmentMode = align
        l.verticalAlignmentMode = .baseline
        addChild(l)
    }

    private func panel(_ rect: CGRect) -> SKShapeNode {
        let p = SKShapeNode(rect: rect, cornerRadius: 14)
        p.fillColor = UIColor(white: 0, alpha: 0.45)
        p.strokeColor = .clear
        p.zPosition = -1
        addChild(p)
        return p
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layout()
    }

    private func layout() {
        guard size.width > 10 else { return }
        if !built { build() }
        let W = size.width, H = size.height
        // SpriteKit origin is bottom-left.
        posLabel.position = CGPoint(x: 80, y: H - 150)
        posTotal.position = CGPoint(x: 80 + posLabel.frame.width + 8, y: H - 150)
        lapLabel.position = CGPoint(x: 84, y: H - 205)
        timeLabel.position = CGPoint(x: 84, y: H - 250)
        bestLabel.position = CGPoint(x: 84, y: H - 290)
        speedLabel.position = CGPoint(x: W - 150, y: 90)
        unitLabel.position = CGPoint(x: W - 140, y: 92)
        gearLabel.position = CGPoint(x: W - 140, y: 140)
        message.position = CGPoint(x: W / 2, y: H * 0.62)
        subMessage.position = CGPoint(x: W / 2, y: H * 0.62 - 70)
        hint.position = CGPoint(x: W / 2, y: 50)
        map.position = CGPoint(x: W - 340, y: H - 340)
        lightsPanel.position = CGPoint(x: W / 2, y: H - 140)
        tower.position = CGPoint(x: 80, y: H - 360)
    }

    private func build() {
        built = true
        label(posLabel, size: 96)
        label(posTotal, size: 44)
        label(lapLabel, size: 40)
        label(timeLabel, size: 34, font: bodyFont)
        label(bestLabel, size: 28, font: bodyFont)
        label(speedLabel, size: 110, align: .right)
        label(unitLabel, size: 30, align: .left)
        unitLabel.text = "km/h"
        label(gearLabel, size: 40, align: .left)
        label(message, size: 120, align: .center)
        label(subMessage, size: 44, font: bodyFont, align: .center)
        label(hint, size: 26, font: bodyFont, align: .center)
        hint.fontColor = UIColor(white: 1, alpha: 0.8)
        message.zPosition = 10
        message.alpha = 0

        // Mini-map
        let box: CGFloat = 260
        let xs = track.pos.map(\.x), zs = track.pos.map(\.y)
        let minX = xs.min()!, maxX = xs.max()!, minZ = zs.min()!, maxZ = zs.max()!
        let span = max(maxX - minX, maxZ - minZ, 1)
        let scale = CGFloat(box / CGFloat(span))
        let ox = (box - CGFloat(maxX - minX) * scale) / 2, oz = (box - CGFloat(maxZ - minZ) * scale) / 2
        mapTransform = { p in CGPoint(x: ox + CGFloat(p.x - minX) * scale, y: box - (oz + CGFloat(p.y - minZ) * scale)) }
        let path = CGMutablePath()
        for (i, p) in track.pos.enumerated() where i % 4 == 0 {
            if i == 0 { path.move(to: mapTransform(p)) } else { path.addLine(to: mapTransform(p)) }
        }
        path.closeSubpath()
        let bg = SKShapeNode(rect: CGRect(x: -20, y: -20, width: box + 40, height: box + 40), cornerRadius: 18)
        bg.fillColor = UIColor(white: 0, alpha: 0.4)
        bg.strokeColor = .clear
        map.addChild(bg)
        let outline = SKShapeNode(path: path)
        outline.strokeColor = UIColor(white: 1, alpha: 0.9)
        outline.lineWidth = 6
        outline.lineJoin = .round
        map.addChild(outline)
        let start = SKShapeNode(circleOfRadius: 6)
        start.fillColor = .white
        start.strokeColor = .black
        start.position = mapTransform(track.pos[0])
        map.addChild(start)
        for (i, color) in carColors.enumerated() {
            let dot = SKShapeNode(circleOfRadius: i == playerIndex ? 11 : 8)
            dot.fillColor = color
            dot.strokeColor = i == playerIndex ? .yellow : .white
            dot.lineWidth = i == playerIndex ? 4 : 2
            dot.zPosition = i == playerIndex ? 3 : 2
            map.addChild(dot)
            mapDots.append(dot)
        }
        addChild(map)

        // Start lights
        let lp = SKShapeNode(rect: CGRect(x: -260, y: -60, width: 520, height: 120), cornerRadius: 20)
        lp.fillColor = UIColor(white: 0.05, alpha: 0.85)
        lp.strokeColor = .clear
        lightsPanel.addChild(lp)
        for i in 0..<5 {
            let l = SKShapeNode(circleOfRadius: 36)
            l.position = CGPoint(x: CGFloat(i - 2) * 96, y: 0)
            l.fillColor = UIColor(white: 0.15, alpha: 1)
            l.strokeColor = UIColor(white: 0.3, alpha: 1)
            l.lineWidth = 3
            lightsPanel.addChild(l)
            lights.append(l)
        }
        lightsPanel.isHidden = true
        addChild(lightsPanel)

        // Timing tower
        for i in 0..<carCount {
            let y = -CGFloat(i) * 40
            let bg = SKShapeNode(rect: CGRect(x: 0, y: y - 10, width: 250, height: 36), cornerRadius: 6)
            bg.fillColor = UIColor(white: 0, alpha: 0.5)
            bg.strokeColor = .clear
            let p = SKLabelNode(fontNamed: font)
            p.fontSize = 24
            p.horizontalAlignmentMode = .center
            p.position = CGPoint(x: 22, y: y)
            p.text = "\(i + 1)"
            let n = SKLabelNode(fontNamed: bodyFont)
            n.fontSize = 24
            n.horizontalAlignmentMode = .left
            n.position = CGPoint(x: 52, y: y)
            tower.addChild(bg)
            tower.addChild(p)
            tower.addChild(n)
            towerRows.append((bg, p, n))
        }
        addChild(tower)
    }

    // MARK: Updates

    func setLights(_ count: Int, visible: Bool) {
        lightsPanel.isHidden = !visible
        for (i, l) in lights.enumerated() {
            l.fillColor = i < count ? UIColor(red: 1, green: 0.08, blue: 0.08, alpha: 1) : UIColor(white: 0.15, alpha: 1)
        }
    }

    func flash(_ text: String, sub: String = "", seconds: TimeInterval = 1.6, color: UIColor = .white) {
        message.text = text
        message.fontColor = color
        subMessage.text = sub
        message.removeAllActions()
        message.alpha = 1
        message.setScale(1.3)
        message.run(.scale(to: 1, duration: 0.15))
        subMessage.alpha = 1
        messageUntil = CACurrentMediaTime() + seconds
    }

    func setHint(_ text: String) { hint.text = text }

    func update(position: Int, laps: (current: Int, total: Int), raceTime: Double, lastLap: Double?, bestLap: Double?,
                speedKmh: Int, gear: Int, cars: [(pos: V2, color: UIColor)], order: [(name: String, color: UIColor, isPlayer: Bool)]) {
        guard built else { return }
        posLabel.text = "P\(position)"
        posTotal.text = "/\(carCount)"
        posTotal.position.x = posLabel.position.x + posLabel.frame.width + 8
        lapLabel.text = "LAP \(min(max(laps.current, 1), laps.total))/\(laps.total)"
        timeLabel.text = RaceHUD.format(raceTime)
        var best = ""
        if let l = lastLap { best += "Last \(RaceHUD.format(l))" }
        if let b = bestLap { best += "   Best \(RaceHUD.format(b))" }
        bestLabel.text = best
        speedLabel.text = "\(speedKmh)"
        gearLabel.text = gear > 0 ? "\(gear)" : "R"
        for (i, c) in cars.enumerated() where i < mapDots.count {
            mapDots[i].position = mapTransform(c.pos)
        }
        for (i, row) in towerRows.enumerated() where i < order.count {
            row.name.text = order[i].name
            row.name.fontColor = order[i].isPlayer ? .yellow : .white
            row.bg.fillColor = order[i].isPlayer ? UIColor(red: 0.6, green: 0.05, blue: 0.05, alpha: 0.8) : UIColor(white: 0, alpha: 0.5)
        }
        if CACurrentMediaTime() > messageUntil && message.alpha > 0 {
            message.alpha = max(0, message.alpha - 0.08)
            subMessage.alpha = message.alpha
        }
    }

    static func format(_ t: Double) -> String {
        guard t.isFinite, t >= 0 else { return "--:--.---" }
        let m = Int(t) / 60
        let s = t - Double(m * 60)
        return String(format: "%d:%06.3f", m, s)
    }
}
