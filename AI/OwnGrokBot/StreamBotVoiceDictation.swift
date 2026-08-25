#if os(iOS)
// StreamBotVoiceDictation.swift
// Talking to a teammate instead of typing at one.
//
//   mic (AVAudioEngine tap) → AsyncStream<AnalyzerInput> → SpeechAnalyzer
//   SpeechTranscriber.results → volatile + finalized text → composer
//
// SpeechAnalyzer is the on-device successor to SFSpeechRecognizer. Two things it
// gives us that the old API did not, and that this controller is built around:
//
//   * Volatile results. Words appear while they are still being spoken and are
//     then revised. This controller keeps volatile and finalized text in
//     separate properties instead of one string, so the composer can render the
//     unsettled tail in grey and the user can see the model correct itself.
//     Concatenating them would throw away the only signal that distinguishes
//     "heard" from "still guessing".
//
//   * On-demand model assets. The locale's speech model is fetched through
//     AssetInventory on first use, which is a multi-hundred-megabyte download.
//     It is surfaced as a real phase rather than a spinner, because otherwise
//     the first tap of the mic looks broken for a minute.
//
// The controller also publishes an audio level from the tap. That is not
// decoration: on a first run, with assets downloading and no text yet, the
// waveform is the only evidence the microphone is working at all.

import AVFoundation
import Foundation
import Observation
import Speech

@MainActor
@Observable
final class StreamBotVoiceDictation {
    enum Phase: Equatable {
        case idle
        /// Permission, asset install, engine spin-up. Carries what it is doing,
        /// because "Downloading the speech model" and "Starting the mic" feel
        /// very different to somebody holding a phone.
        case preparing(String)
        case listening
        case failed(String)

        var isActive: Bool {
            switch self {
            case .listening: true
            case .preparing: true
            default: false
            }
        }
    }

    private(set) var phase: Phase = .idle
    /// Speech the transcriber has committed to.
    private(set) var finalizedText = ""
    /// The unsettled tail. Replaced wholesale on every revision.
    private(set) var volatileText = ""
    /// Smoothed mic level, 0…1, for the waveform.
    private(set) var level: Float = 0

    var isListening: Bool { phase == .listening }

    /// Everything heard this session — what the composer commits on stop.
    var transcript: String {
        (finalizedText + volatileText).trimmingCharacters(in: .whitespaces)
    }

    var hasTranscript: Bool { !transcript.isEmpty }

    private var audioEngine: AVAudioEngine?
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?

    // MARK: - Control

    func start() async {
        guard !phase.isActive else { return }
        finalizedText = ""
        volatileText = ""
        level = 0

        do {
            phase = .preparing("Checking microphone access")
            guard await AVAudioApplication.requestRecordPermission() else {
                throw StreamBotError("Microphone access is off. Turn it on in Settings to dictate.")
            }

            let locale = await SpeechTranscriber.supportedLocale(equivalentTo: .current)
                ?? Locale(identifier: "en-US")
            let transcriber = SpeechTranscriber(
                locale: locale,
                transcriptionOptions: [],
                reportingOptions: [.volatileResults],
                attributeOptions: []
            )
            self.transcriber = transcriber

            // First use of a locale pulls its speech model down. This can take a
            // while on a slow connection, so it gets its own phase.
            if let request = try await AssetInventory.assetInstallationRequest(
                supporting: [transcriber]
            ) {
                phase = .preparing("Downloading the speech model")
                try await request.downloadAndInstall()
            }

            phase = .preparing("Starting the microphone")
            let analyzer = SpeechAnalyzer(modules: [transcriber])
            self.analyzer = analyzer

            guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
                compatibleWith: [transcriber]
            ) else {
                throw StreamBotError("This device has no audio format the transcriber can use.")
            }

            let (inputSequence, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
            inputContinuation = continuation

            resultsTask = Task { [weak self] in
                do {
                    for try await result in transcriber.results {
                        let text = String(result.text.characters)
                        self?.consume(text: text, isFinal: result.isFinal)
                    }
                } catch {
                    self?.phase = .failed(error.localizedDescription)
                }
            }

            try await startAudioEngine(streamingInto: continuation, format: analyzerFormat)
            try await analyzer.start(inputSequence: inputSequence)
            phase = .listening
        } catch {
            await teardown()
            phase = .failed(error.localizedDescription)
        }
    }

    /// Stops listening and returns everything heard.
    @discardableResult
    func stop() async -> String {
        inputContinuation?.finish()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        // Flush buffered audio into final results before tearing down, so the
        // last word spoken is not dropped by the stop tap.
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        await resultsTask?.value

        let result = transcript
        await teardown()
        phase = .idle
        level = 0
        return result
    }

    /// Abandons the session and keeps nothing.
    func cancel() async {
        _ = await stop()
        finalizedText = ""
        volatileText = ""
    }

    private func teardown() async {
        resultsTask?.cancel()
        resultsTask = nil
        inputContinuation = nil
        analyzer = nil
        transcriber = nil
        audioEngine = nil
        await CoreAIAudioSession.deactivate()
    }

    // MARK: - Results

    private func consume(text: String, isFinal: Bool) {
        if isFinal {
            finalizedText += text
            volatileText = ""
        } else {
            volatileText = text
        }
    }

    private func publish(level newValue: Float) {
        // Asymmetric smoothing: rise fast so a sudden word is visible on the
        // very next frame, fall slowly so the bars decay instead of flickering
        // to zero between syllables.
        let coefficient: Float = newValue > level ? 0.55 : 0.12
        level += (newValue - level) * coefficient
    }

    // MARK: - Audio capture

    private func startAudioEngine(
        streamingInto continuation: AsyncStream<AnalyzerInput>.Continuation,
        format analyzerFormat: AVAudioFormat
    ) async throws {
        try await CoreAIAudioSession.configureAndActivate(
            category: .playAndRecord,
            mode: .spokenAudio,
            options: [.duckOthers, .defaultToSpeaker],
            activeOptions: .notifyOthersOnDeactivation
        )

        let engine = AVAudioEngine()
        audioEngine = engine
        let input = engine.inputNode
        let micFormat = input.outputFormat(forBus: 0)
        let converter = AVAudioConverter(from: micFormat, to: analyzerFormat)

        let tap: AVAudioNodeTapBlock = { [weak self] buffer, _ in
            let level = Self.meterLevel(of: buffer)
            Task { @MainActor [weak self] in
                self?.publish(level: level)
            }
            guard let converted = Self.convert(buffer, with: converter, to: analyzerFormat) else {
                return
            }
            continuation.yield(AnalyzerInput(buffer: converted))
        }

        if #available(iOS 27.0, *) {
            try Self.installTap(on: input, bufferSize: 4096, format: micFormat, block: tap)
        } else {
            input.installTap(onBus: 0, bufferSize: 4096, format: micFormat, block: tap)
        }
        engine.prepare()
        try engine.start()
    }

    /// On iOS 27 the Swift overlay for `installTap` traps, so the tap goes in
    /// through the Objective-C selector that takes an error out-parameter. Same
    /// workaround the other voice apps in this project use.
    @available(iOS 27.0, *)
    private nonisolated static func installTap(
        on node: AVAudioNode,
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
            throw StreamBotError("This device cannot install an audio input tap.")
        }
        let install = unsafeBitCast(method, to: InstallTapIMP.self)
        var error: NSError?
        guard install(node, selector, 0, bufferSize, format, &error, block) else {
            throw error ?? StreamBotError("The audio input tap could not be installed.")
        }
    }

    /// RMS of the buffer, mapped onto a 0…1 scale through decibels.
    ///
    /// Raw RMS is useless for a waveform: normal speech sits near the bottom of
    /// a linear 0…1 scale and the bars barely move. Converting to dB and mapping
    /// a 50 dB window spreads speech across the full height.
    private nonisolated static func meterLevel(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for index in 0..<count {
            let sample = channel[index]
            sum += sample * sample
        }
        let rms = (sum / Float(count)).squareRoot()
        guard rms > 0 else { return 0 }
        let decibels = 20 * log10(rms)
        let floor: Float = -50
        return min(max((decibels - floor) / -floor, 0), 1)
    }

    /// Converts a mic buffer to the analyzer's format. Runs on the tap thread.
    private nonisolated static func convert(
        _ buffer: AVAudioPCMBuffer,
        with converter: AVAudioConverter?,
        to format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        guard let converter else { return buffer }
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up) + 16)
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            return nil
        }
        var fed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if fed {
                status.pointee = .noDataNow
                return nil
            }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        return error == nil && output.frameLength > 0 ? output : nil
    }
}
#endif
