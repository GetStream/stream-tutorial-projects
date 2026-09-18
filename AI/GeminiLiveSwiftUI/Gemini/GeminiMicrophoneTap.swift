import AVFAudio
import Foundation
import os
import StreamVideo
import StreamWebRTC

/// A pass-through Stream Video `AudioFilter` that taps the microphone signal
/// WebRTC has already captured (and echo-cancelled / noise-suppressed), then
/// resamples it to 16 kHz mono Int16 PCM for the Gemini Live API.
///
/// The filter never mutates the buffer, so what Stream sends to the call is
/// unchanged. Muting the call microphone stops capture, which naturally stops
/// audio flowing to Gemini as well.
nonisolated final class GeminiMicrophoneTap: AudioFilter, @unchecked Sendable {
    let id = "gemini-microphone-tap"

    /// Receives ~100 ms chunks of 16 kHz mono Int16 PCM. Called on the audio thread.
    var onChunk: (@Sendable (Data) -> Void)? {
        get { lock.withLock { $0.onChunk } }
        set { lock.withLock { $0.onChunk = newValue } }
    }

    /// When false, captured audio is dropped (used for half-duplex gating while
    /// the model is speaking).
    var isForwarding: Bool {
        get { lock.withLock { $0.isForwarding } }
        set { lock.withLock { $0.isForwarding = newValue } }
    }

    static let outputSampleRate: Double = 16_000

    private struct State {
        var onChunk: (@Sendable (Data) -> Void)?
        var isForwarding = true
    }

    private let lock = OSAllocatedUnfairLock(initialState: State())
    private let logger = Logger(subsystem: "io.getstream.streamlive", category: "MicTap")

    // Audio-thread-only state (WebRTC calls initialize/applyEffect serially).
    private var converter: AVAudioConverter?
    private var inputFormat: AVAudioFormat?
    private var inputBuffer: AVAudioPCMBuffer?
    private var outputBuffer: AVAudioPCMBuffer?
    private var pending = Data()
    private let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: GeminiMicrophoneTap.outputSampleRate,
        channels: 1,
        interleaved: true
    )!

    func initialize(sampleRate: Int, channels: Int) {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(sampleRate),
            channels: 1,
            interleaved: false
        ) else { return }
        inputFormat = format
        converter = AVAudioConverter(from: format, to: outputFormat)
        converter?.sampleRateConverterQuality = AVAudioQuality.medium.rawValue
        // WebRTC hands us 10 ms frames; leave headroom for larger blocks.
        inputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleRate / 10) * 4)
        outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(Self.outputSampleRate / 10) * 4 + 64)
        pending.removeAll(keepingCapacity: true)
        logger.info("initialized sampleRate=\(sampleRate) channels=\(channels)")
    }

    func applyEffect(to audioBuffer: inout RTCAudioBuffer) {
        let (forwarding, callback) = lock.withLock { ($0.isForwarding, $0.onChunk) }
        guard forwarding, let callback,
              let converter, let inputBuffer, let outputBuffer,
              audioBuffer.channels > 0 else { return }

        let frames = AVAudioFrameCount(audioBuffer.frames)
        guard frames > 0, frames <= inputBuffer.frameCapacity,
              let destination = inputBuffer.floatChannelData?[0] else { return }

        // Mono tap of channel 0 - WebRTC capture is mono on iOS anyway.
        let source = audioBuffer.rawBuffer(forChannel: 0)
        destination.update(from: source, count: Int(frames))
        inputBuffer.frameLength = frames

        outputBuffer.frameLength = 0
        var consumed = false
        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return inputBuffer
        }
        guard status != .error, error == nil, outputBuffer.frameLength > 0,
              let int16 = outputBuffer.int16ChannelData?[0] else { return }

        pending.append(UnsafeBufferPointer(start: int16, count: Int(outputBuffer.frameLength)))

        if pending.count >= StreamLiveConfig.micChunkBytes {
            callback(pending)
            pending = Data()
        }
    }

    func release() {
        converter = nil
        inputBuffer = nil
        outputBuffer = nil
        pending.removeAll()
    }
}
