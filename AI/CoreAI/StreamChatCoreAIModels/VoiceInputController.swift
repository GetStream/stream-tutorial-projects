// VoiceInputController.swift
// One voice-input surface for the chat composer, two ASR engines:
//
//   * SpeechAnalyzer (default) — streaming SpeechTranscriber results are
//     pushed into the composer text live (via DictationController).
//   * Whisper (Core AI)        — records a clip, then transcribes with the
//     whisper-large-v3-turbo export.
//
// The engine is chosen from AIModelPreferences (model settings sheet in the
// message screen's trailing toolbar).

import Foundation
import Observation

@MainActor
@Observable
final class VoiceInputController {
    enum Phase: Equatable {
        case idle
        case preparing
        case listening          // streaming (SpeechAnalyzer)
        case recording          // batch clip capture (Core AI engines)
        case transcribing
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    var isActive: Bool {
        switch phase {
        case .listening, .recording, .preparing, .transcribing: true
        default: false
        }
    }

    var errorMessage: String? {
        if case .failed(let message) = phase { return message }
        return nil
    }

    private let dictation = DictationController()
    private let recorder = AudioClipRecorder()

    #if canImport(CoreAI)
    // Loaded lazily and kept warm; keyed by the engine that loaded them.
    private var loadedWhisper: (model: SpeechToTextModel, engine: WhisperCoreAITranscriber)?
    #endif

    /// Mic button entry point. `currentText` is the composer draft when the
    /// session starts; `onUpdate` receives the updated draft.
    func toggle(
        model: SpeechToTextModel,
        currentText: String,
        onUpdate: @escaping (String) -> Void
    ) {
        if isActive {
            Task { await stop(currentText: currentText, onUpdate: onUpdate) }
        } else {
            start(model: model, currentText: currentText, onUpdate: onUpdate)
        }
    }

    private var activeModel: SpeechToTextModel = .speechAnalyzer

    private func start(
        model: SpeechToTextModel,
        currentText: String,
        onUpdate: @escaping (String) -> Void
    ) {
        activeModel = model
        switch model {
        case .speechAnalyzer:
            phase = .listening
            dictation.toggle(currentText: currentText, onUpdate: onUpdate)

        case .whisperLargeV3Turbo:
            guard model.isInstalled else {
                phase = .failed(
                    "\(model.displayName) is not installed. Open the model settings and tap Get to download it."
                )
                return
            }
            Task {
                do {
                    phase = .preparing
                    try await recorder.start()
                    phase = .recording
                } catch {
                    phase = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func stop(currentText: String, onUpdate: @escaping (String) -> Void) async {
        switch activeModel {
        case .speechAnalyzer:
            dictation.stopIfNeeded()
            phase = .idle

        case .whisperLargeV3Turbo:
            let samples = await recorder.stop()
            phase = .transcribing
            do {
                let text = try await transcribe(samples: samples, model: activeModel)
                if !text.isEmpty {
                    let prefix = currentText.isEmpty || currentText.hasSuffix(" ")
                        ? currentText : currentText + " "
                    onUpdate(prefix + text)
                }
                phase = .idle
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func dismissError() {
        if case .failed = phase { phase = .idle }
    }

    private func transcribe(samples: [Float], model: SpeechToTextModel) async throws -> String {
        #if canImport(CoreAI)
        guard let modelURL = model.installedModelURL else {
            throw NSError(
                domain: "VoiceInput", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "\(model.displayName) export not found."]
            )
        }
        switch model {
        case .whisperLargeV3Turbo:
            let engine: WhisperCoreAITranscriber
            if let loaded = loadedWhisper, loaded.model == model {
                engine = loaded.engine
            } else {
                engine = try await WhisperCoreAITranscriber(modelURL: modelURL)
                loadedWhisper = (model, engine)
            }
            return try await engine.transcribe(samples: samples)

        case .speechAnalyzer:
            return ""
        }
        #else
        throw NSError(
            domain: "VoiceInput", code: 2,
            userInfo: [NSLocalizedDescriptionKey:
                "Core AI is unavailable in this environment (e.g. the iOS Simulator). "
                + "Use SpeechAnalyzer, or run on a device."]
        )
        #endif
    }
}
