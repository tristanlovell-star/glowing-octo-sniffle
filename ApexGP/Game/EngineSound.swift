import AVFoundation

/// A synthesised engine note (and tyre squeal) for the player's car.
final class EngineSound {
    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?

    /// Written from the game loop, read on the audio thread. Plain floats are
    /// fine here: a stale value for one buffer is inaudible.
    private final class Synth {
        var rpm: Float = 0.2
        var load: Float = 0
        var squeal: Float = 0
        var volume: Float = 0
        var phase: Float = 0, phase2: Float = 0, lp: Float = 0, squealPhase: Float = 0
        var noiseState: UInt32 = 22222
    }
    private let synth = Synth()
    private let electric: Bool

    init(electric: Bool) {
        self.electric = electric
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient)
        try? session.setActive(true)

        let format = engine.outputNode.inputFormat(forBus: 0)
        let sampleRate = Float(format.sampleRate > 0 ? format.sampleRate : 48000)
        let st = synth
        let electric = self.electric

        let node = AVAudioSourceNode { _, _, frameCount, bufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            let rpm = st.rpm, load = st.load, vol = st.volume, sq = st.squeal
            let freq: Float = electric ? 180 + rpm * 1400 : 38 + rpm * 210
            var phase = st.phase, phase2 = st.phase2, lp = st.lp, squealPhase = st.squealPhase
            var noiseState = st.noiseState
            defer {
                st.phase = phase; st.phase2 = phase2; st.lp = lp
                st.squealPhase = squealPhase; st.noiseState = noiseState
            }
            for frame in 0..<Int(frameCount) {
                phase += freq / sampleRate
                if phase >= 1 { phase -= 1 }
                phase2 += freq * 0.5 / sampleRate
                if phase2 >= 1 { phase2 -= 1 }
                var v: Float
                if electric {
                    v = sin(phase * 2 * .pi) * 0.5 + sin(phase * 4 * .pi) * 0.15
                } else {
                    let saw = phase * 2 - 1
                    let square: Float = phase2 < 0.5 ? 1 : -1
                    let raw = saw * (0.55 + load * 0.35) + square * 0.35
                    lp += (raw - lp) * (0.18 + rpm * 0.25)
                    v = lp
                }
                // Tyre squeal: a wobbly high tone mixed with noise.
                if sq > 0.01 {
                    squealPhase += (1500 + 300 * sin(squealPhase * 0.002)) / sampleRate
                    if squealPhase >= 1000 { squealPhase -= 1000 }
                    noiseState = noiseState &* 1664525 &+ 1013904223
                    let noise = Float(noiseState >> 9) / Float(1 << 23) - 1
                    v += (sin(squealPhase * 2 * .pi) * 0.25 + noise * 0.1) * sq
                }
                let out = v * vol * 0.22
                for b in buffers {
                    b.mData?.assumingMemoryBound(to: Float.self)[frame] = out
                }
            }
            return noErr
        }
        source = node
        let monoFormat = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: monoFormat)
        try? engine.start()
    }

    func update(rpm: Float, load: Float, squeal: Float, volume: Float) {
        synth.rpm = rpm
        synth.load = load
        synth.squeal = squeal
        synth.volume = volume
    }

    func stop() {
        synth.volume = 0
        engine.stop()
    }
}
