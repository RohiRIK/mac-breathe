import AVFoundation
import MacBreatheCore

/// Every breath sound plays through one running `AVAudioEngine`, scheduled ahead on the audio clock so
/// it starts exactly on the phase change (minus the output device's latency).
///
/// Recorded choices (handpan, bowl, chimes, birds, rain stick) are short CC0 clips in the bundle.
/// Ocean and Warm Pad are synthesized to the length of the phase, so the sound itself breathes: Ocean = soft filtered noise that swells and brightens on the in-breath and
/// recedes on the out-breath; Pad = a low warm chord that swells and fades the same way. Cached.
@MainActor
final class SoundEngine {
    enum Sound: Hashable {
        case ocean(Phase, tenths: Int)
        case pad(Phase, tenths: Int)
        /// A clip in the app bundle: `Contents/Resources/Sounds/<name>.m4a`.
        case file(String)
    }

    private static let rate = 44_100.0
    private let engine = AVAudioEngine()
    /// A few players so a sound can fade out while the next fades in.
    private let players = (0..<4).map { _ in AVAudioPlayerNode() }
    /// Background loop, on its own player so breath sounds never cut it.
    private let background = AVAudioPlayerNode()
    private var fade: Task<Void, Never>?
    private let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
    private var next = 0
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]

    init() {
        for player in players + [background] {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
    }

    /// Start the engine and render sounds before the session needs them.
    func prepare(_ sounds: [Sound]) {
        start()
        for sound in sounds { _ = buffer(sound) }
    }

    /// Play `sound` `delay` seconds from now (0 = now), on the audio clock.
    func play(_ sound: Sound, volume: Float, in delay: Double = 0) {
        guard start(), let buffer = buffer(sound) else { return }
        let player = players[next]
        next = (next + 1) % players.count
        player.stop()
        player.volume = volume
        player.scheduleBuffer(buffer)
        let lead = max(delay - engine.outputNode.presentationLatency, 0)
        player.play(at: AVAudioTime(hostTime: mach_absolute_time() + AVAudioTime.hostTime(forSeconds: lead)))
    }

    /// Loop `sound` quietly for the session, fading in over 3 s.
    func startBackground(_ sound: Sound, volume: Float) {
        guard start(), let buffer = buffer(sound) else { return }
        background.stop()
        background.volume = 0
        background.scheduleBuffer(buffer, at: nil, options: .loops)
        background.play()
        ramp(to: volume, over: 3)
    }

    /// Fade the background out over 3 s, then stop it.
    func stopBackground() {
        guard background.isPlaying else { return }
        ramp(to: 0, over: 3) { [background] in background.stop() }
    }

    private func ramp(to target: Float, over seconds: Double, then done: (() -> Void)? = nil) {
        fade?.cancel()
        let from = background.volume, steps = Int(seconds * 20)
        fade = Task {
            for i in 1...steps {
                try? await Task.sleep(for: .milliseconds(50))
                if Task.isCancelled { return }
                background.volume = from + (target - from) * Float(i) / Float(steps)
            }
            done?()
        }
    }

    /// Pause the engine after a session so it does not keep the audio device awake.
    func idle() {
        fade?.cancel()
        (players + [background]).forEach { $0.stop() }
        engine.pause()
        buffers = [:]  // About 2 MB per sound; rendered again in milliseconds.
    }

    @discardableResult
    private func start() -> Bool {
        if engine.isRunning { return true }
        do { try engine.start() } catch { return false }  // No output device: stay silent.
        return true
    }

    private func buffer(_ sound: Sound) -> AVAudioPCMBuffer? {
        if let cached = buffers[sound] { return cached }
        let made: AVAudioPCMBuffer? = switch sound {
        case .file(let name): Bundle.main.url(forResource: name, withExtension: "m4a", subdirectory: "Sounds").flatMap(load)
        case .ocean(let phase, let tenths): render(phase, seconds: Double(tenths) / 10, voice: .ocean)
        case .pad(let phase, let tenths): render(phase, seconds: Double(tenths) / 10, voice: .pad)
        }
        buffers[sound] = made
        return made
    }

    /// Reads a clip and converts it to the engine format (stereo, 44.1 kHz, float).
    private func load(_ url: URL) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url),
              let source = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: source)) != nil,
              let converter = AVAudioConverter(from: file.processingFormat, to: format) else { return nil }
        let capacity = AVAudioFrameCount(Double(source.frameLength) * format.sampleRate / file.processingFormat.sampleRate) + 4096
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        nonisolated(unsafe) var fed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if fed { status.pointee = .endOfStream; return nil }
            fed = true
            status.pointee = .haveData
            return source
        }
        return error == nil ? out : nil
    }

    // MARK: Synthesis

    private enum Voice { case ocean, pad }

    /// Loudness over a phase (0…1 of the phase), so the sound follows the orb.
    private static func envelope(_ phase: Phase, _ p: Double) -> Double {
        let ease = (1 - cos(.pi * min(max(p, 0), 1))) / 2
        switch phase {
        case .inhale: return 0.15 + 0.85 * ease  // swell
        case .exhale: return 1 - ease  // recede
        case .hold: return 0.3 * (1 - ease)  // a quiet glow that settles
        case .rest: return 0
        }
    }

    /// Brightness over a phase: Ocean's filter opens on the in-breath and closes on the out-breath.
    private static func cutoff(_ phase: Phase, _ p: Double) -> Double {
        let ease = (1 - cos(.pi * min(max(p, 0), 1))) / 2
        switch phase {
        case .inhale: return 280 + 820 * ease
        case .exhale: return 1100 - 850 * ease
        case .hold, .rest: return 500
        }
    }

    private func render(_ phase: Phase, seconds: Double, voice: Voice) -> AVAudioPCMBuffer {
        // A soft fade in, and a tail after the phase so one breath flows into the next.
        let fadeIn = 0.25, tail = 0.6
        let total = seconds + tail
        let frames = Int(total * Self.rate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buffer.frameLength = AVAudioFrameCount(frames)
        var random = SystemRandomNumberGenerator()
        var low = [0.0, 0.0], low2 = [0.0, 0.0]
        var phases = [Double](repeating: 0, count: Self.chord.count)
        for i in 0..<frames {
            let t = Double(i) / Self.rate
            let p = t / seconds
            var level = Self.envelope(phase, min(p, 1)) * min(t / fadeIn, 1)
            if t > seconds { level *= max(1 - (t - seconds) / tail, 0) }
            switch voice {
            case .ocean:
                // Two-pole low-passed noise, independent per channel for width.
                let a = exp(-2 * .pi * Self.cutoff(phase, min(p, 1)) / Self.rate)
                for c in 0..<2 {
                    let white = Double.random(in: -1...1, using: &random)
                    low[c] = (1 - a) * white + a * low[c]
                    low2[c] = (1 - a) * low[c] + a * low2[c]
                    buffer.floatChannelData![c][i] = Float(low2[c] * level * 2.2)
                }
            case .pad:
                var s = 0.0
                for (k, (freq, amp)) in Self.chord.enumerated() {
                    phases[k] += 2 * .pi * freq / Self.rate
                    s += amp * sin(phases[k])
                }
                let v = Float(s * level * 0.09)
                buffer.floatChannelData![0][i] = v
                buffer.floatChannelData![1][i] = v
            }
        }
        return buffer
    }

    /// A low open fifth with gently detuned twins (slow beating, no sharp partials).
    private static let chord: [(Double, Double)] = [(110, 1), (110.4, 0.7), (164.8, 0.6), (165.3, 0.4), (220, 0.35)]
}
