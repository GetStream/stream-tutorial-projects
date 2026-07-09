// AudioClipRecorder.swift
// Records microphone audio into a 16 kHz mono Float32 buffer for the
// Core AI ASR engines (Whisper, Wav2Vec 2.0). Uses the same
// AVAudioEngine tap + AVAudioConverter approach as DictationController.

import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class AudioClipRecorder {
    static let sampleRate: Double = 16000

    private(set) var isRecording = false
    /// Live input level (0...1) for a simple recording meter.
    private(set) var level: Float = 0

    private var audioEngine: AVAudioEngine?
    private let sink = SampleSink()

    /// Thread-safe sample accumulator fed from the audio tap thread.
    private final class SampleSink: @unchecked Sendable {
        private let lock = NSLock()
        private var samples: [Float] = []

        func reset() {
            lock.withLock { samples.removeAll() }
        }

        func append(_ chunk: [Float]) {
            lock.withLock { samples.append(contentsOf: chunk) }
        }

        func drain() -> [Float] {
            lock.withLock {
                let result = samples
                samples = []
                return result
            }
        }
    }

    func start() async throws {
        guard !isRecording else { return }
        guard await AVAudioApplication.requestRecordPermission() else {
            throw NSError(
                domain: "AudioClipRecorder", code: 1,
                userInfo: [NSLocalizedDescriptionKey:
                    "Microphone access denied. Enable it in Settings to dictate."]
            )
        }

        #if os(iOS)
        try await CoreAIAudioSession.configureAndActivate(
            category: .playAndRecord,
            mode: .spokenAudio,
            options: [.duckOthers, .defaultToSpeaker],
            activeOptions: .notifyOthersOnDeactivation
        )
        #endif

        sink.reset()

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(
                domain: "AudioClipRecorder", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Could not create 16 kHz format."]
            )
        }

        let engine = AVAudioEngine()
        audioEngine = engine
        let input = engine.inputNode
        let micFormat = input.outputFormat(forBus: 0)
        let converter = AVAudioConverter(from: micFormat, to: targetFormat)

        let sink = sink
        let tap: AVAudioNodeTapBlock = { [weak self] buffer, _ in
            guard let converted = Self.convert(buffer, with: converter, to: targetFormat),
                  let channel = converted.floatChannelData?[0]
            else { return }
            let frames = Int(converted.frameLength)
            let chunk = Array(UnsafeBufferPointer(start: channel, count: frames))
            sink.append(chunk)
            let peak = chunk.reduce(Float(0)) { max($0, abs($1)) }
            Task { @MainActor [weak self] in self?.level = min(peak * 4, 1) }
        }

        if #available(iOS 27.0, *) {
            try Self.installTap(input, bus: 0, bufferSize: 4096, format: micFormat, block: tap)
        } else {
            input.installTap(onBus: 0, bufferSize: 4096, format: micFormat, block: tap)
        }
        engine.prepare()
        try engine.start()
        isRecording = true
    }

    /// Stops recording and returns the captured 16 kHz mono samples.
    func stop() async -> [Float] {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRecording = false
        level = 0
        #if os(iOS)
        await CoreAIAudioSession.deactivate()
        #endif
        return sink.drain()
    }

    // MARK: - Tap plumbing (shared with DictationController's iOS 27 workaround)

    @available(iOS 27.0, *)
    private nonisolated static func installTap(
        _ node: AVAudioNode,
        bus: AVAudioNodeBus,
        bufferSize: AVAudioFrameCount,
        format: AVAudioFormat?,
        block: @escaping AVAudioNodeTapBlock
    ) throws {
        let selector = NSSelectorFromString("installTapOnBus:bufferSize:format:error:block:")
        typealias InstallTapIMP = @convention(c) (
            AVAudioNode,
            Selector,
            AVAudioNodeBus,
            AVAudioFrameCount,
            AVAudioFormat?,
            UnsafeMutablePointer<NSError?>?,
            @escaping AVAudioNodeTapBlock
        ) -> Bool
        guard let method = node.method(for: selector) else {
            throw NSError(
                domain: "AudioClipRecorder", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "AVAudioNode tap installer is unavailable."]
            )
        }
        let install = unsafeBitCast(method, to: InstallTapIMP.self)
        var error: NSError?
        guard install(node, selector, bus, bufferSize, format, &error, block) else {
            throw error ?? NSError(
                domain: "AudioClipRecorder", code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Could not install the input tap."]
            )
        }
    }

    private nonisolated static func convert(
        _ buffer: AVAudioPCMBuffer,
        with converter: AVAudioConverter?,
        to format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        guard let converter else { return buffer }
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up) + 16)
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            return nil
        }
        var fed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if fed {
                status.pointee = .noDataNow
                return nil
            }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        return error == nil && out.frameLength > 0 ? out : nil
    }
}
