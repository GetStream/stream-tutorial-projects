import Foundation
import os

/// Which Gemini audio model the session talks to.
nonisolated enum GeminiLiveMode: String, CaseIterable, Identifiable, Sendable {
    /// Gemini 3.8 Live - native speech-to-speech with visual context.
    case live
    /// Gemini 3.8 Live Extended Thinking - deeper background reasoning.
    case liveThinking
    /// Gemini 3.5 Transcribe (live) - transcription-only pipeline, no voice reply.
    case transcribe

    var id: String { rawValue }

    var model: String {
        switch self {
        case .live: StreamLiveConfig.geminiLiveModel
        case .liveThinking: StreamLiveConfig.geminiLiveThinkingModel
        case .transcribe: StreamLiveConfig.geminiTranscribeModel
        }
    }

    var title: String {
        switch self {
        case .live: "Gemini 3.8 Live"
        case .liveThinking: "3.8 Live · Extended Thinking"
        case .transcribe: "3.5 Transcribe · Live captions"
        }
    }

    var shortTitle: String {
        switch self {
        case .live: "Live"
        case .liveThinking: "Thinking"
        case .transcribe: "Transcribe"
        }
    }

    var symbol: String {
        switch self {
        case .live: "waveform"
        case .liveThinking: "brain"
        case .transcribe: "text.quote"
        }
    }

    /// Transcribe sessions are audio-in / text-out; they never speak or see.
    var speaks: Bool { self != .transcribe }
    var acceptsVideo: Bool { self != .transcribe }
}

/// Server events surfaced to the view model.
enum GeminiLiveEvent: Sendable {
    case setupComplete
    /// Raw 16-bit little-endian PCM at 24 kHz, mono.
    case audio(Data)
    /// Incremental transcript of what the user said.
    case inputTranscript(String)
    /// Incremental transcript of what the model is saying.
    case outputTranscript(String)
    /// Text parts (TEXT response modality or mixed turns).
    case modelText(String)
    case turnComplete
    case generationComplete
    case interrupted
    case goAway(timeLeft: String?)
    case closed(Error?)
}

enum GeminiLiveError: LocalizedError {
    case missingAPIKey
    case setupFailed(String)
    case notConnected

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "Gemini API key is missing. Add GEMINI_API_KEY to ~/.zprofile and regenerate Secrets.swift."
        case let .setupFailed(reason): "Gemini Live setup failed: \(reason)"
        case .notConnected: "Gemini Live session is not connected."
        }
    }
}

/// Thin raw-WebSocket client for the Gemini Live API
/// (`BidiGenerateContent`). One instance == one session.
///
/// Wire format (v1beta):
/// - client -> `{"setup": {...}}` once, then `{"realtimeInput": {...}}` /
///   `{"clientContent": {...}}`
/// - server -> `{"setupComplete": {}}`, `{"serverContent": {...}}`, `{"goAway": {...}}`
nonisolated final class GeminiLiveSession: NSObject, @unchecked Sendable {
    let events: AsyncStream<GeminiLiveEvent>

    private let continuation: AsyncStream<GeminiLiveEvent>.Continuation
    private let apiKey: String
    private let sendQueue = DispatchQueue(label: "io.getstream.streamlive.gemini.send", qos: .userInitiated)
    private let stateLock = OSAllocatedUnfairLock(initialState: State())
    private let logger = Logger(subsystem: "io.getstream.streamlive", category: "GeminiLive")

    private struct State {
        var urlSession: URLSession?
        var task: URLSessionWebSocketTask?
        var isReady = false
        var setupContinuation: CheckedContinuation<Void, Error>?
    }

    init(apiKey: String) {
        self.apiKey = apiKey
        var continuation: AsyncStream<GeminiLiveEvent>.Continuation!
        events = AsyncStream(bufferingPolicy: .unbounded) { continuation = $0 }
        self.continuation = continuation
        super.init()
    }

    var isReady: Bool { stateLock.withLock { $0.isReady } }

    // MARK: Lifecycle

    /// Opens the socket, sends the `setup` message and waits for `setupComplete`.
    func connect(mode: GeminiLiveMode, voice: String, systemInstruction: String) async throws {
        guard !apiKey.isEmpty else { throw GeminiLiveError.missingAPIKey }

        var components = URLComponents(string: "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent")!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        let urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = urlSession.webSocketTask(with: components.url!)
        task.maximumMessageSize = 16 * 1024 * 1024
        stateLock.withLock {
            $0.urlSession = urlSession
            $0.task = task
        }
        task.resume()

        try await send(json: ["setup": Self.setupPayload(mode: mode, voice: voice, systemInstruction: systemInstruction)])

        try await withCheckedThrowingContinuation { (setup: CheckedContinuation<Void, Error>) in
            stateLock.withLock { $0.setupContinuation = setup }
            receiveNext()
        }
    }

    func disconnect() {
        let (task, urlSession) = stateLock.withLock { state -> (URLSessionWebSocketTask?, URLSession?) in
            let pair = (state.task, state.urlSession)
            state.task = nil
            state.urlSession = nil
            state.isReady = false
            return pair
        }
        task?.cancel(with: .normalClosure, reason: nil)
        urlSession?.finishTasksAndInvalidate()
        continuation.finish()
    }

    // MARK: Sending

    /// Streams a chunk of raw 16-bit PCM microphone audio.
    func sendAudio(_ pcm: Data, sampleRate: Int) {
        enqueue([
            "realtimeInput": [
                "audio": [
                    "data": pcm.base64EncodedString(),
                    "mimeType": "audio/pcm;rate=\(sampleRate)"
                ]
            ]
        ])
    }

    /// Streams one JPEG camera frame (<= 1 fps).
    func sendVideoFrame(_ jpeg: Data) {
        enqueue([
            "realtimeInput": [
                "video": [
                    "data": jpeg.base64EncodedString(),
                    "mimeType": "image/jpeg"
                ]
            ]
        ])
    }

    /// Sends a typed user turn. `turnComplete: true` also interrupts any
    /// in-flight generation, which is what we want for a new question.
    func sendText(_ text: String) {
        enqueue([
            "clientContent": [
                "turns": [["role": "user", "parts": [["text": text]]]],
                "turnComplete": true
            ]
        ])
    }

    /// Tells the server the mic stream paused (e.g. user muted) so VAD can
    /// finalize the current utterance.
    func sendAudioStreamEnd() {
        enqueue(["realtimeInput": ["audioStreamEnd": true]])
    }

    // MARK: Setup payload

    private static func setupPayload(mode: GeminiLiveMode, voice: String, systemInstruction: String) -> [String: Any] {
        var setup: [String: Any] = ["model": "models/\(mode.model)"]

        switch mode {
        case .transcribe:
            setup["generationConfig"] = ["responseModalities": ["TEXT"]]
            // Transcribe-live is a dedicated speech-to-text pipeline: no system
            // prompt, no output transcription. English only for now.
            setup["inputAudioTranscription"] = ["languageCodes": [StreamLiveConfig.geminiLanguageCode]]

        case .live, .liveThinking:
            var generation: [String: Any] = [
                "responseModalities": ["AUDIO"],
                "speechConfig": [
                    "voiceConfig": ["prebuiltVoiceConfig": ["voiceName": voice]],
                    "languageCode": StreamLiveConfig.geminiLanguageCode
                ]
            ]
            if mode == .liveThinking {
                // `thinkingLevel` must be omitted for gemini-3.8-live and is
                // low/medium/high for the extended-thinking model.
                generation["thinkingConfig"] = ["thinkingLevel": "low"]
            }
            setup["generationConfig"] = generation
            setup["systemInstruction"] = ["parts": [["text": systemInstruction]]]
            // Pin both transcribers to English; without a hint the input-side
            // ASR auto-detects and short utterances get mislabelled (e.g. "tu sais").
            setup["inputAudioTranscription"] = ["languageCodes": [StreamLiveConfig.geminiLanguageCode]]
            setup["outputAudioTranscription"] = ["languageCodes": [StreamLiveConfig.geminiLanguageCode]]
            setup["realtimeInputConfig"] = [
                "automaticActivityDetection": [
                    "disabled": false,
                    "startOfSpeechSensitivity": "START_SENSITIVITY_HIGH",
                    "endOfSpeechSensitivity": "END_SENSITIVITY_HIGH",
                    "prefixPaddingMs": 40,
                    "silenceDurationMs": 500
                ]
            ]
        }
        return setup
    }

    // MARK: Plumbing

    private func enqueue(_ payload: [String: Any]) {
        sendQueue.async { [weak self] in
            guard let self, let task = self.stateLock.withLock({ $0.isReady ? $0.task : nil }) else { return }
            guard let data = try? JSONSerialization.data(withJSONObject: payload),
                  let string = String(data: data, encoding: .utf8) else { return }
            task.send(.string(string)) { [weak self] error in
                if let error { self?.logger.error("send failed: \(error.localizedDescription)") }
            }
        }
    }

    private func send(json payload: [String: Any]) async throws {
        guard let task = stateLock.withLock({ $0.task }) else { throw GeminiLiveError.notConnected }
        let data = try JSONSerialization.data(withJSONObject: payload)
        try await task.send(.string(String(decoding: data, as: UTF8.self)))
    }

    private func receiveNext() {
        guard let task = stateLock.withLock({ $0.task }) else { return }
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(message):
                switch message {
                case let .data(data): self.handle(data)
                case let .string(text): self.handle(Data(text.utf8))
                @unknown default: break
                }
                self.receiveNext()
            case let .failure(error):
                self.finish(with: error)
            }
        }
    }

    private func handle(_ data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.error("unparseable server message (\(data.count) bytes)")
            return
        }

        if object["setupComplete"] != nil {
            let pending = stateLock.withLock { state -> CheckedContinuation<Void, Error>? in
                state.isReady = true
                let c = state.setupContinuation
                state.setupContinuation = nil
                return c
            }
            pending?.resume()
            continuation.yield(.setupComplete)
            return
        }

        if let error = object["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "unknown error"
            finish(with: GeminiLiveError.setupFailed(message))
            return
        }

        if let goAway = object["goAway"] as? [String: Any] {
            continuation.yield(.goAway(timeLeft: goAway["timeLeft"] as? String))
            return
        }

        guard let content = object["serverContent"] as? [String: Any] else { return }

        if let turn = content["modelTurn"] as? [String: Any],
           let parts = turn["parts"] as? [[String: Any]] {
            for part in parts {
                if let inline = part["inlineData"] as? [String: Any],
                   let base64 = inline["data"] as? String,
                   let audio = Data(base64Encoded: base64) {
                    continuation.yield(.audio(audio))
                }
                if let text = part["text"] as? String, !text.isEmpty {
                    continuation.yield(.modelText(text))
                }
            }
        }
        if let transcript = content["inputTranscription"] as? [String: Any],
           let text = transcript["text"] as? String, !text.isEmpty {
            continuation.yield(.inputTranscript(text))
        }
        if let transcript = content["outputTranscription"] as? [String: Any],
           let text = transcript["text"] as? String, !text.isEmpty {
            continuation.yield(.outputTranscript(text))
        }
        if content["interrupted"] as? Bool == true { continuation.yield(.interrupted) }
        if content["generationComplete"] as? Bool == true { continuation.yield(.generationComplete) }
        if content["turnComplete"] as? Bool == true { continuation.yield(.turnComplete) }
    }

    private func finish(with error: Error?) {
        let pending = stateLock.withLock { state -> CheckedContinuation<Void, Error>? in
            state.isReady = false
            state.task = nil
            let c = state.setupContinuation
            state.setupContinuation = nil
            return c
        }
        if let pending {
            pending.resume(throwing: error ?? GeminiLiveError.setupFailed("connection closed before setup completed"))
        }
        if let error { logger.error("session closed: \(error.localizedDescription)") }
        continuation.yield(.closed(error))
        continuation.finish()
    }
}

nonisolated extension GeminiLiveSession: URLSessionWebSocketDelegate {
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let text = reason.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        logger.info("socket closed code=\(closeCode.rawValue) reason=\(text)")
        let error: Error? = closeCode == .normalClosure ? nil : GeminiLiveError.setupFailed(text.isEmpty ? "closed (\(closeCode.rawValue))" : text)
        finish(with: error)
    }
}
