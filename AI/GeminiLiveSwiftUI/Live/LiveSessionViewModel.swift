import Combine
import Foundation
import os
import StreamVideo
import SwiftUI

struct TranscriptEntry: Identifiable, Equatable {
    enum Role { case user, model }

    let id = UUID()
    let role: Role
    var text: String
    var isFinal = false
    let startedAt = Date()
}

enum LivePhase: Equatable {
    case idle
    case connecting
    case listening
    case speaking
    case reconnecting
    case failed(String)

    var label: String {
        switch self {
        case .idle: "Ready"
        case .connecting: "Connecting to Gemini"
        case .listening: "Listening"
        case .speaking: "Speaking"
        case .reconnecting: "Reconnecting"
        case .failed: "Connection failed"
        }
    }
}

/// Orchestrates one live session:
/// Stream call (camera + mic) -> `GeminiMicrophoneTap` / `GeminiFrameTap` ->
/// `GeminiLiveSession` -> `GeminiAudioPlayer` + transcript.
final class LiveSessionViewModel: ObservableObject {
    @Published var mode: GeminiLiveMode = .live
    @Published private(set) var phase: LivePhase = .idle
    @Published private(set) var transcript: [TranscriptEntry] = []
    @Published private(set) var isModelSpeaking = false
    @Published var isTranscriptPresented = false
    @Published var toast: String?

    /// When off (default) the mic is gated while Gemini speaks, so speaker
    /// audio can't re-trigger the model; use "Tap to interrupt" instead. Turn
    /// on with headphones for hands-free barge-in.
    @Published var allowsVoiceInterruptions = false {
        didSet { micTap.isForwarding = allowsVoiceInterruptions || !isModelSpeaking }
    }

    /// Mirrors the Stream call's mic state so the UI and Gemini stay in sync.
    @Published private(set) var isMicMuted = false

    nonisolated let micTap = GeminiMicrophoneTap()
    nonisolated let frameTap = GeminiFrameTap()
    private let player = GeminiAudioPlayer()

    /// The live session, readable from the audio/video capture threads.
    private nonisolated let sessionBox = OSAllocatedUnfairLock<GeminiLiveSession?>(initialState: nil)
    private var session: GeminiLiveSession? {
        get { sessionBox.withLock { $0 } }
        set { sessionBox.withLock { $0 = newValue } }
    }
    private var eventTask: Task<Void, Never>?
    private weak var call: Call?
    private var wantsSession = false
    private var reconnectAttempts = 0

    /// Latest model utterance for the on-camera caption strip.
    var latestModelText: String? {
        transcript.last(where: { $0.role == .model })?.text
    }

    /// Latest user utterance for the on-camera caption strip.
    var latestUserText: String? {
        transcript.last(where: { $0.role == .user })?.text
    }

    init() {
        let sessionBox = sessionBox
        micTap.onChunk = { chunk in
            sessionBox.withLock { $0 }?.sendAudio(chunk, sampleRate: Int(GeminiMicrophoneTap.outputSampleRate))
        }
        frameTap.onFrame = { jpeg in
            sessionBox.withLock { $0 }?.sendVideoFrame(jpeg)
        }
        player.onSpeakingChange = { [weak self] speaking in
            self?.handleSpeakingChange(speaking)
        }
    }

    // MARK: Stream call hookup

    /// Called once the Stream call is joined. Installs the pass-through filters
    /// that feed Gemini and opens the Gemini session.
    func attach(call: Call) {
        guard self.call !== call else { return }
        self.call = call
        call.setAudioFilter(micTap)
        call.setVideoFilter(frameTap.filter)
        wantsSession = true
        reconnectAttempts = 0
        Task { await openSession() }
    }

    func micStateChanged(isOn: Bool) {
        let muted = !isOn
        guard muted != isMicMuted else { return }
        isMicMuted = muted
        if muted { session?.sendAudioStreamEnd() }
    }

    func cameraStateChanged(isOn: Bool) {
        frameTap.isEnabled = isOn && mode.acceptsVideo
    }

    /// Tears everything down (leaving the Stream call is the view's job).
    func stop() {
        wantsSession = false
        eventTask?.cancel()
        eventTask = nil
        session?.disconnect()
        session = nil
        player.stop()
        call?.setAudioFilter(nil)
        call?.setVideoFilter(nil)
        call = nil
        isModelSpeaking = false
        phase = .idle
    }

    // MARK: Session controls

    func switchMode(_ newMode: GeminiLiveMode) {
        guard newMode != mode else { return }
        mode = newMode
        frameTap.isEnabled = newMode.acceptsVideo
        finalizeOpenEntries()
        guard wantsSession else { return }
        Task { await restartSession() }
    }

    /// "Tap to interrupt": cut the voice locally and reopen the mic.
    func interrupt() {
        guard isModelSpeaking || phase == .speaking else { return }
        player.interrupt()
        finalizeOpenEntries()
        isModelSpeaking = false
        micTap.isForwarding = true
        phase = .listening
    }

    /// Typed prompt from the transcript composer.
    func sendText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let session, session.isReady else { return }
        player.interrupt()
        finalizeOpenEntries()
        transcript.append(TranscriptEntry(role: .user, text: trimmed, isFinal: true))
        session.sendText(trimmed)
    }

    func clearTranscript() {
        transcript.removeAll()
    }

    // MARK: Session lifecycle

    private func openSession() async {
        session?.disconnect()
        eventTask?.cancel()

        let session = GeminiLiveSession(apiKey: StreamLiveConfig.geminiAPIKey)
        self.session = session
        phase = reconnectAttempts > 0 ? .reconnecting : .connecting
        micTap.isForwarding = true
        frameTap.isEnabled = mode.acceptsVideo

        do {
            try await session.connect(
                mode: mode,
                voice: StreamLiveConfig.geminiVoice,
                systemInstruction: StreamLiveConfig.systemInstruction
            )
        } catch {
            phase = .failed(error.localizedDescription)
            return
        }

        reconnectAttempts = 0
        phase = .listening
        eventTask = Task { [weak self] in
            for await event in session.events {
                guard let self, !Task.isCancelled else { break }
                self.handle(event)
            }
        }
    }

    private func restartSession() async {
        player.interrupt()
        isModelSpeaking = false
        await openSession()
    }

    private func handle(_ event: GeminiLiveEvent) {
        switch event {
        case .setupComplete:
            phase = .listening

        case let .audio(data):
            guard mode.speaks else { return }
            player.enqueue(data)

        case let .inputTranscript(text):
            append(text, to: .user)

        case let .outputTranscript(text), let .modelText(text):
            // The user's turn is over once the model starts answering.
            if let index = transcript.lastIndex(where: { $0.role == .user && !$0.isFinal }) {
                transcript[index].isFinal = true
            }
            append(text, to: .model)
            if mode.speaks, !isModelSpeaking { phase = .speaking }

        case .generationComplete:
            if let index = transcript.lastIndex(where: { $0.role == .model && !$0.isFinal }) {
                transcript[index].isFinal = true
            }

        case .turnComplete:
            finalizeOpenEntries()
            if !isModelSpeaking { phase = .listening }

        case .interrupted:
            player.interrupt()
            finalizeOpenEntries()
            isModelSpeaking = false
            micTap.isForwarding = true
            phase = .listening

        case let .goAway(timeLeft):
            toast = "Gemini is rotating the session\(timeLeft.map { " in \($0)" } ?? "")…"

        case let .closed(error):
            eventTask = nil
            guard wantsSession else { return }
            if reconnectAttempts < 3 {
                reconnectAttempts += 1
                phase = .reconnecting
                let attempt = reconnectAttempts
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(Double(attempt)))
                    guard let self, self.wantsSession else { return }
                    await self.openSession()
                }
            } else {
                phase = .failed(error?.localizedDescription ?? "Gemini closed the session.")
            }
        }
    }

    private func handleSpeakingChange(_ speaking: Bool) {
        isModelSpeaking = speaking
        micTap.isForwarding = allowsVoiceInterruptions || !speaking
        if speaking {
            phase = .speaking
        } else if phase == .speaking {
            phase = .listening
            finalizeOpenEntries()
        }
    }

    // MARK: Transcript bookkeeping

    private func append(_ text: String, to role: TranscriptEntry.Role) {
        if let index = transcript.lastIndex(where: { $0.role == role && !$0.isFinal }) {
            transcript[index].text += text
        } else {
            transcript.append(TranscriptEntry(role: role, text: text.trimmingCharacters(in: .whitespaces)))
        }
    }

    private func finalizeOpenEntries() {
        for index in transcript.indices where !transcript[index].isFinal {
            transcript[index].isFinal = true
            transcript[index].text = transcript[index].text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        transcript.removeAll { $0.text.isEmpty }
    }
}
