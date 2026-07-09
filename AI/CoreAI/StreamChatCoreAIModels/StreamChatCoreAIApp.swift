// StreamChatCoreAIApp.swift
// StreamChatCoreAIModels — a Stream Chat SwiftUI messaging app wired to
// on-device AI:
//
//   * Voice input       — SpeechAnalyzer + SpeechTranscriber (default),
//                         Whisper / Wav2Vec 2.0 Core AI exports as alternatives.
//   * Text refinement   — Apple Intelligence Foundation Models (default) or
//                         Core AI zoo language bundles (Qwen, LFM, Granite).
//   * Photo Q&A         — MiniCPM-V 4.6 (Core AI zoo export): attach a photo,
//                         ask about it, and the answer streams into the chat.
//
// Chat backend: Stream (app "StreamChatCoreAIModels", app_id 1660832).

#if os(iOS)
import StreamChat
import StreamChatSwiftUI
import SwiftUI

/// Owns the Stream Chat client for the whole app. Initialized once before
/// any SDK view renders; never recreated.
@MainActor
final class StreamCoreAIChatService {
    static let shared = StreamCoreAIChatService()

    private(set) var streamChat: StreamChat?
    private(set) var chatClient: ChatClient?

    private init() {}

    /// Stream credentials for the demo user. The API key is public;
    /// the token is a CLI-minted user JWT (no API secret ships in the app).
    private enum Credentials {
        static let apiKey = "4dz7gst7phy5"
        static let userId = "amos"
        static let userName = "Amos Gyamfi"
        static let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE3ODMwMTAyOTEsInVzZXJfaWQiOiJhbW9zIn0.nh8-jdEHgloLXjhCzem-qtxcNILAk-a_5uBOHEl1KZk"
    }

    func setUpIfNeeded() {
        guard streamChat == nil else { return }

        var config = ChatClientConfig(apiKey: .init(Credentials.apiKey))
        config.isLocalStorageEnabled = true
        let client = ChatClient(config: config)
        chatClient = client
        streamChat = StreamChat(chatClient: client)

        let userInfo = UserInfo(
            id: Credentials.userId,
            name: Credentials.userName,
            imageURL: nil
        )
        client.connectUser(
            userInfo: userInfo,
            token: Token(stringLiteral: Credentials.token)
        ) { error in
            if let error {
                print("Stream connect failed: \(error)")
            }
        }
    }
}

/// Root view of the chat app. Creating it initializes the Stream client
/// before any SDK view renders (required by StreamChatSwiftUI).
struct StreamChatCoreAIRootView: View {
    init() {
        StreamCoreAIChatService.shared.setUpIfNeeded()
    }

    var body: some View {
        ChatChannelListView(
            viewFactory: StreamCoreAIViewFactory.shared,
            title: "Core AI Chat"
        )
    }
}
#endif
