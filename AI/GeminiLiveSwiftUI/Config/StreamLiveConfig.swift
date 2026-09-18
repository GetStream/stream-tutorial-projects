import CoreGraphics
import Foundation

/// Client-side configuration. Stream credentials are the same Stream app (and
/// CLI-minted user token) used by the sibling StreamChatSwiftAI project - one
/// Stream API key covers Chat and Video. The Gemini key lives in the gitignored
/// `Secrets.swift`.
nonisolated enum StreamLiveConfig {
    // MARK: Stream

    static let streamAPIKey = "ddwdnyxnm5h9"
    static let userId = "aurora"
    static let userName = "Aurora"
    static let userImageURL = URL(string: "https://api.dicebear.com/9.x/glass/png?seed=aurora")
    static let userToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE3ODg3NzAwMTAsInVzZXJfaWQiOiJhdXJvcmEifQ.MhNSkgCtrnJEKqE8qzhE7SbQjW0uEMQFRJ__rIuyJb4"

    /// Every live session is its own Stream call so the camera/mic pipeline is
    /// owned by Stream Video and other participants could join later.
    static let callType = "default"
    static func makeCallId() -> String {
        "stream-live-" + UUID().uuidString.lowercased().prefix(8)
    }

    // MARK: Gemini

    static let geminiAPIKey = Secrets.geminiAPIKey
    static let geminiLiveModel = "gemini-3.8-live"
    static let geminiLiveThinkingModel = "gemini-3.8-live-extended-thinking"
    static let geminiTranscribeModel = "gemini-3.5-transcribe-live"

    /// Prebuilt Live API voice. Others: Puck, Charon, Kore, Fenrir, Leda, Orus, Zephyr.
    static let geminiVoice = "Aoede"

    /// English only for now. Applied to the Live voice (`speechConfig.languageCode`)
    /// and to the Transcribe pipeline (`inputAudioTranscription.languageCodes`).
    static let geminiLanguageCode = "en-US"

    static let systemInstruction = """
    You are Aurora, a friendly real-time assistant running inside an iOS app. \
    The user is pointing their phone camera at the world and talking to you. \
    You receive a live camera frame about once per second - use it to answer \
    questions about what the user is looking at: identify objects, read labels \
    and signs, explain how things work, and give step-by-step help. \
    Always speak and respond in English only, even if the user speaks another \
    language or the camera shows text in another language - in that case, \
    describe or translate it into English. \
    Be concise and conversational; answer in one to three short sentences \
    unless the user asks for detail. If the camera view is unclear, say what you \
    can see and ask the user to move closer or hold steady.
    """

    /// Frames are throttled to the Live API's 1 fps ceiling and downscaled so
    /// each JPEG stays around 60-120 KB.
    static let frameInterval: TimeInterval = 1.0
    static let frameMaxDimension: CGFloat = 768
    static let frameJPEGQuality: CGFloat = 0.6

    /// Mic audio is batched into ~100 ms chunks (16 kHz mono Int16 = 3200 bytes).
    static let micChunkBytes = 3200

    static let starterPrompts = [
        "What am I looking at?",
        "Read this label out loud",
        "What is this used for?",
        "How do I fix this?",
        "Is this safe to use?",
        "Describe the scene"
    ]
}
