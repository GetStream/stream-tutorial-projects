import AVFAudio
import Foundation
import os

/// Plays the model's 24 kHz mono Int16 PCM chunks as they stream in.
///
/// Uses `AVAudioEngine` + `AVAudioPlayerNode` on the audio session Stream
/// Video already configured (`playAndRecord`, speaker). Chunks are converted to
/// Float32 and scheduled back-to-back; `interrupt()` flushes everything so a
/// barge-in cuts the voice immediately.
nonisolated final class GeminiAudioPlayer: @unchecked Sendable {
    static let sampleRate: Double = 24_000

    /// Fires on the main queue when playback transitions between speaking and idle.
    var onSpeakingChange: (@MainActor (Bool) -> Void)?

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: GeminiAudioPlayer.sampleRate, channels: 1)!
    private let queue = DispatchQueue(label: "io.getstream.streamlive.gemini.playback")
    private let logger = Logger(subsystem: "io.getstream.streamlive", category: "AudioOut")

    private var scheduled = 0
    private var generation = 0
    private var isSpeaking = false
    private var observer: NSObjectProtocol?

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        observer = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self] _ in
            self?.queue.async { self?.restartIfNeeded() }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func enqueue(_ pcm16: Data) {
        queue.async { [self] in
            guard startIfNeeded() else { return }
            let sampleCount = pcm16.count / 2
            guard sampleCount > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)),
                  let channel = buffer.floatChannelData?[0] else { return }

            pcm16.withUnsafeBytes { raw in
                let samples = raw.bindMemory(to: Int16.self)
                for i in 0..<sampleCount {
                    channel[i] = Float(Int16(littleEndian: samples[i])) / 32768
                }
            }
            buffer.frameLength = AVAudioFrameCount(sampleCount)

            scheduled += 1
            let generation = generation
            setSpeaking(true)
            player.scheduleBuffer(buffer) { [weak self] in
                self?.queue.async {
                    guard let self, self.generation == generation else { return }
                    self.scheduled -= 1
                    if self.scheduled <= 0 {
                        self.scheduled = 0
                        self.setSpeaking(false)
                    }
                }
            }
            if !player.isPlaying { player.play() }
        }
    }

    /// Drops every queued chunk and stops the voice right now.
    func interrupt() {
        queue.async { [self] in
            generation += 1
            scheduled = 0
            player.stop()
            setSpeaking(false)
        }
    }

    func stop() {
        queue.async { [self] in
            generation += 1
            scheduled = 0
            player.stop()
            engine.stop()
            setSpeaking(false)
        }
    }

    // MARK: Private (playback queue)

    private func startIfNeeded() -> Bool {
        guard !engine.isRunning else { return true }
        do {
            engine.prepare()
            try engine.start()
            return true
        } catch {
            logger.error("engine start failed: \(error.localizedDescription)")
            return false
        }
    }

    private func restartIfNeeded() {
        guard scheduled > 0 || player.isPlaying else { return }
        engine.connect(player, to: engine.mainMixerNode, format: format)
        _ = startIfNeeded()
        if !player.isPlaying { player.play() }
    }

    private func setSpeaking(_ speaking: Bool) {
        guard speaking != isSpeaking else { return }
        isSpeaking = speaking
        guard let onSpeakingChange else { return }
        Task { @MainActor in onSpeakingChange(speaking) }
    }
}
