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

        // Synthesize soft percussive clicks for positive/negative feedback
        let sr: Double = format.sampleRate > 0 ? format.sampleRate : 44_100
        let channels = max(format.channelCount, AVAudioChannelCount(1))
        positiveBuffer = ToneSynth.makeClick(
            sampleRate: sr,
            channels: channels,
            duration: 0.12,
            baseFrequency: 1800,
            accentFrequency: 3400,
            gain: 0.45
        )

        negativeBuffer = ToneSynth.makeClick(
            sampleRate: sr,
            channels: channels,
            duration: 0.12,
            baseFrequency: 900,
            accentFrequency: 1500,
            gain: 0.38
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

    static func makeClick(
        sampleRate sr: Double,
        channels: AVAudioChannelCount,
        duration: Double,
        baseFrequency: Double,
        accentFrequency: Double,
        gain: Double
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
            let fastDecay = exp(-t * 40)
            let slowDecay = exp(-t * 28)
            let main = sin(2.0 * .pi * baseFrequency * t) * slowDecay
            let accent = sin(2.0 * .pi * accentFrequency * t) * fastDecay * 0.6
            let highClick = sin(2.0 * .pi * min(baseFrequency * 6, 6000) * t) * fastDecay * 0.25
            let sample = Float((main + accent + highClick) * gain * 0.5)
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
