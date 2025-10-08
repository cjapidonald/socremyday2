import AVFoundation

final class SoundManager {
    static let shared = SoundManager()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var positiveBuffer: AVAudioPCMBuffer?
    private var negativeBuffer: AVAudioPCMBuffer?
    private var configured = false

    /// Respect the device’s Silent switch by using .ambient (do NOT force .playback).
    /// Call once on app start (e.g., in App init) so the first sound isn’t delayed.
    func preload() {
        guard !configured else { return }
        configured = true

        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // If audio session fails, we’ll still try to play quietly.
        }

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)

        let format = engine.mainMixerNode.outputFormat(forBus: 0)

        // Synthesize short pleasant chime and subtle low click
        let sr: Double = format.sampleRate > 0 ? format.sampleRate : 44_100
        let channels = max(format.channelCount, AVAudioChannelCount(1))
        positiveBuffer = ToneSynth.makeChord(
            sampleRate: sr,
            channels: channels,
            duration: 0.25,
            partials: [
                .init(freq: 880,  gain: 0.9),   // A5
                .init(freq: 1320, gain: 0.5),   // E6 (pleasant fifth)
                .init(freq: 1760, gain: 0.25)   // A6 octave
            ],
            attack: 0.008, release: 0.08, curve: .exp
        )

        negativeBuffer = ToneSynth.makeSweep(
            sampleRate: sr,
            channels: channels,
            duration: 0.18,
            startFreq: 380,
            endFreq: 240,
            gain: 0.9,
            attack: 0.004,
            release: 0.05,
            curve: .exp
        )

        startEngineIfNeeded()
    }

    /// Positive sound (pleasant chime)
    func positive() {
        guard AppPrefsStore.shared.soundsOn else { return }
        guard let buf = positiveBuffer else { return }
        // The call to startEngineIfNeeded() is moved to the schedule function
        schedule(buffer: buf)
    }

    /// Negative sound (soft low sweep/click)
    func negative() {
        guard AppPrefsStore.shared.soundsOn else { return }
        guard let buf = negativeBuffer else { return }
        // The call to startEngineIfNeeded() is moved to the schedule function
        schedule(buffer: buf)
    }

    private func startEngineIfNeeded() {
        // This function is now always called on the audio processing queue.
        if !engine.isRunning {
            do { try engine.start() } catch { /* ignore */ }
        }
        if !player.isPlaying {
            player.play()
        }
    }

    private let queue = DispatchQueue(label: "SoundManager.queue")
    private func schedule(buffer: AVAudioPCMBuffer) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // **FIX:** Ensure the engine is running *before* scheduling the buffer.
            // This prevents a race condition and the resulting crash.
            self.startEngineIfNeeded()
            self.player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        }
    }
}

/// Tiny DSP helpers — no assets needed.
enum ToneEnvCurve { case lin, exp }

struct ToneSynth {

    struct Partial { let freq: Double; let gain: Double }

    static func makeChord(
        sampleRate sr: Double,
        channels: AVAudioChannelCount,
        duration: Double,
        partials: [Partial],
        attack: Double,
        release: Double,
        curve: ToneEnvCurve
    ) -> AVAudioPCMBuffer? {
        guard sr > 0 else { return nil }

        let channelCount = Int(channels)
        guard channelCount > 0 else { return nil }

        let nFrames = AVAudioFrameCount(duration * sr)
        let format = AVAudioFormat(standardFormatWithSampleRate: sr, channels: channels)!
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: nFrames) else { return nil }
        buf.frameLength = nFrames
        guard let basePtr = buf.floatChannelData else { return nil }
        let channelPtrs = UnsafeBufferPointer(start: basePtr, count: channelCount)

        for i in 0..<Int(nFrames) {
            let t = Double(i) / sr
            var x: Double = 0
            for p in partials {
                x += p.gain * sin(2.0 * .pi * p.freq * t)
            }
            let env = envelope(t: t, dur: duration, a: attack, r: release, curve: curve)
            let sample = Float(x * env * 0.4) // master gain
            for ch in 0..<channelCount {
                channelPtrs[ch][i] = sample
            }
        }
        return buf
    }

    static func makeSweep(
        sampleRate sr: Double,
        channels: AVAudioChannelCount,
        duration: Double,
        startFreq: Double,
        endFreq: Double,
        gain: Double,
        attack: Double,
        release: Double,
        curve: ToneEnvCurve
    ) -> AVAudioPCMBuffer? {
        guard sr > 0 else { return nil }

        let channelCount = Int(channels)
        guard channelCount > 0 else { return nil }

        let nFrames = AVAudioFrameCount(duration * sr)
        let format = AVAudioFormat(standardFormatWithSampleRate: sr, channels: channels)!
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: nFrames) else { return nil }
        buf.frameLength = nFrames
        guard let basePtr = buf.floatChannelData else { return nil }
        let channelPtrs = UnsafeBufferPointer(start: basePtr, count: channelCount)

        for i in 0..<Int(nFrames) {
            let t = Double(i) / sr
            // Exponential-ish sweep
            let f = startFreq * pow(endFreq / startFreq, t / duration)
            let phase = 2.0 * .pi * f * t
            let env = envelope(t: t, dur: duration, a: attack, r: release, curve: curve)
            let sample = Float(sin(phase) * env * gain * 0.35)
            for ch in 0..<channelCount {
                channelPtrs[ch][i] = sample
            }
        }
        return buf
    }

    private static func envelope(t: Double, dur: Double, a: Double, r: Double, curve: ToneEnvCurve) -> Double {
        let sustainStart = a
        let sustainEnd = max(dur - r, sustainStart)
        switch curve {
        case .lin:
            if t < sustainStart { return t / max(a, 0.0001) }
            if t > sustainEnd { return max(0, 1 - (t - sustainEnd) / max(r, 0.0001)) }
            return 1.0
        case .exp:
            if t < sustainStart { return min(1.0, pow(t / max(a, 0.0001), 0.6)) }
            if t > sustainEnd { return pow(max(0, 1 - (t - sustainEnd) / max(r, 0.0001)), 2.2) }
            return 1.0
        }
    }
}
