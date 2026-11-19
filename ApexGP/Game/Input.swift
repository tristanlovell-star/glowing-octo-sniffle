import GameController

/// Reads the Siri Remote or any connected game controller.
///
/// Siri Remote: slide your thumb left/right on the touch surface to steer,
/// press the clickpad to brake. The car accelerates by itself.
/// Controller: left stick steers, right trigger (or A) accelerates,
/// left trigger (or X) brakes, Y changes camera.
final class InputReader {
    private(set) var usingRemote = true
    private var lastCameraButton = false

    init() {
        for c in GCController.controllers() { configure(c) }
        NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] note in
            if let c = note.object as? GCController { self?.configure(c) }
        }
    }

    private func configure(_ c: GCController) {
        if let micro = c.microGamepad {
            micro.reportsAbsoluteDpadValues = true
            micro.allowsRotation = false
        }
    }

    struct State {
        var steer: Float = 0
        var throttle: Float = 0
        var brake: Float = 0
        var hasThrottleControl = false
        var cameraPressed = false
    }

    func read() -> State {
        var s = State()
        var cameraDown = false
        let controllers = GCController.controllers()
        if let pad = controllers.compactMap({ $0.extendedGamepad }).first {
            usingRemote = false
            var steer = pad.leftThumbstick.xAxis.value
            if abs(steer) < 0.08 { steer = 0 }
            steer += pad.dpad.xAxis.value
            s.steer = clampf(steer, -1, 1)
            s.throttle = max(pad.rightTrigger.value, pad.buttonA.isPressed ? 1 : 0)
            s.brake = max(pad.leftTrigger.value, pad.buttonX.isPressed ? 1 : 0)
            s.hasThrottleControl = true
            cameraDown = pad.buttonY.isPressed
        } else if let micro = controllers.compactMap({ $0.microGamepad }).first {
            usingRemote = true
            var x = micro.dpad.xAxis.value
            if abs(x) < 0.12 { x = 0 }
            // A little extra reach so full lock doesn't need the very edge.
            s.steer = clampf(x * 1.25, -1, 1)
            s.brake = micro.buttonA.isPressed ? 1 : 0
            s.hasThrottleControl = false
            cameraDown = micro.buttonX.isPressed
        }
        s.cameraPressed = cameraDown && !lastCameraButton
        lastCameraButton = cameraDown
        return s
    }
}
