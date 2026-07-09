#if os(iOS)
// MiniCPMChatResponder.swift
// Photo Q&A in chat: when the user sends a message that contains a photo
// attachment plus a question, MiniCPM-V 4.6 looks at the photo on-device and
// streams its answer into the channel as an incoming message.
//
// The answer arrives in an *incoming* bubble because it is sent by a second
// Stream user — "MiniCPM-V 4.6" (id `minicpm-ai`) — connected with its own
// lightweight ChatClient. The flow:
//
//   1. `willSendMessage` fires while the composer still holds the draft
//      text and attachments → capture the question + first photo.
//   2. The photo goes through the SigLIP vision encoder once; the user's
//      message (photo + question) uploads through Stream's normal media path.
//   3. The bot joins the channel (add-member is idempotent), posts a
//      placeholder message, and edits it with the streamed tokens
//      (throttled) until the answer is complete.

import StreamChat
import StreamChatSwiftUI
import SwiftUI

@MainActor
@Observable
final class MiniCPMChatResponder {
    static let shared = MiniCPMChatResponder()
    private init() {}

    enum Phase: Equatable {
        case idle
        case loading
        case reading
        case answering
        case failed(String)
    }

    private(set) var phase: Phase = .idle

    var isBusy: Bool {
        switch phase {
        case .loading, .reading, .answering: true
        default: false
        }
    }

    var errorMessage: String? {
        if case .failed(let message) = phase { return message }
        return nil
    }

    func dismissError() {
        if case .failed = phase { phase = .idle }
    }

    /// Bot identity. The API key matches the main app; the token is a
    /// CLI-minted user JWT for `minicpm-ai` (no API secret ships in the app).
    private enum Bot {
        static let apiKey = "4dz7gst7phy5"
        static let userId = "minicpm-ai"
        static let userName = "MiniCPM-V 4.6"
        static let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE3ODMzMzE5ODEsInVzZXJfaWQiOiJtaW5pY3BtLWFpIn0.14vdTV4jjGSKFFI6RyfM1ptINbiem_pVW3IQBKHArmg"
    }

    #if canImport(CoreAI)
    private var engine: MiniCPMVisionEngine?
    private var loadedModelID: String?
    #endif
    private var botClient: ChatClient?
    private var activeTask: Task<Void, Never>?

    /// Called from `willSendMessage`, while the composer still holds the
    /// draft. Triggers photo Q&A when the selected MiniCPM model is installed
    /// and the outgoing message has a photo and a question.
    func handleSentMessage(from composerViewModel: MessageComposerViewModel) {
        // Editing an existing message is not a new question.
        guard composerViewModel.editedMessage?.wrappedValue == nil else { return }

        let question = composerViewModel.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        let model = AIModelPreferences.shared.visionModel
        guard model.isInstalled else { return }

        let photo: UIImage? = composerViewModel.composerAssets
            .compactMap { asset -> UIImage? in
                guard case .addedAsset(let added) = asset, added.type == .image else {
                    return nil
                }
                return added.image
            }
            .first
        guard let photo, let cgImage = photo.cgImage else { return }
        guard let cid = composerViewModel.channelController.cid else { return }

        answer(question: question, cgImage: cgImage, model: model, in: cid)
    }

    // MARK: - Answer pipeline

    private func answer(
        question: String,
        cgImage: CGImage,
        model: VisionLanguageModel,
        in cid: ChannelId
    ) {
        #if canImport(CoreAI)
        guard !isBusy else { return }
        activeTask?.cancel()
        activeTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.runAnswer(
                    question: question, cgImage: cgImage, model: model, in: cid
                )
                self.phase = .idle
            } catch is CancellationError {
                self.phase = .idle
            } catch {
                self.phase = .failed(error.localizedDescription)
            }
        }
        #else
        phase = .failed("MiniCPM needs the Core AI runtime — run on a physical device.")
        #endif
    }

    #if canImport(CoreAI)
    private func runAnswer(
        question: String,
        cgImage: CGImage,
        model: VisionLanguageModel,
        in cid: ChannelId
    ) async throws {
        // 1. Load (or reuse) the engine and encode the photo.
        if engine == nil || loadedModelID != model.id {
            phase = .loading
            engine = nil
            let fresh = MiniCPMVisionEngine()
            try await fresh.load(model: model)
            engine = fresh
            loadedModelID = model.id
        }
        guard let engine else { return }

        phase = .reading
        try await engine.attach(cgImage: cgImage)

        // 2. Bot joins the channel and posts a placeholder message. Membership
        //    must be confirmed *before* the bot watches the channel, and the
        //    watch must succeed before posting — `createNewMessage` writes to
        //    the bot client's local store and fails with ChannelDoesNotExist
        //    if the channel was never fetched.
        let client = try await connectedBotClient()
        await ensureBotMembership(in: cid)
        let channelController = client.channelController(for: cid)
        let messageId = try await createBotMessage(
            in: channelController,
            text: "Looking at the photo…"
        )
        let messageController = client.messageController(cid: cid, messageId: messageId)

        // 3. Stream the answer into the message, throttled to spare the API.
        phase = .answering
        var latest = ""
        var lastPush = ContinuousClock.now
        var pushInFlight = false
        try await engine.generate(question: question) { text in
            latest = text
            let now = ContinuousClock.now
            guard !pushInFlight, now - lastPush > .milliseconds(700), !text.isEmpty else {
                return
            }
            lastPush = now
            pushInFlight = true
            messageController.partialUpdateMessage(text: text) { _ in
                pushInFlight = false
            }
        }

        // 4. Final full text (also covers answers shorter than one throttle tick).
        let answer = latest.trimmingCharacters(in: .whitespacesAndNewlines)
        try await finalizeBotMessage(
            messageController,
            text: answer.isEmpty ? "I could not come up with an answer for that photo." : answer
        )
    }
    #endif

    // MARK: - Stream plumbing (bot side)

    private func connectedBotClient() async throws -> ChatClient {
        if let botClient { return botClient }
        var config = ChatClientConfig(apiKey: .init(Bot.apiKey))
        config.isLocalStorageEnabled = false
        let client = ChatClient(config: config)
        _ = try await client.connectUser(
            userInfo: UserInfo(id: Bot.userId, name: Bot.userName, imageURL: nil),
            token: Token(stringLiteral: Bot.token)
        )
        botClient = client
        return client
    }

    /// Adds the bot to the channel with the *user's* client (members may add
    /// members) and waits for the server round-trip. Idempotent server-side;
    /// errors are non-fatal because the bot may already be a member.
    private func ensureBotMembership(in cid: ChannelId) async {
        guard let userClient = StreamCoreAIChatService.shared.chatClient else { return }
        await withCheckedContinuation { continuation in
            userClient.channelController(for: cid)
                .addMembers(userIds: [Bot.userId]) { _ in
                    continuation.resume()
                }
        }
    }

    /// Watches the channel with the bot client (so it exists in the bot's
    /// local store — `createNewMessage` fails with ChannelDoesNotExist
    /// otherwise), then posts the placeholder. Retried because the watch can
    /// race the just-granted membership.
    private func createBotMessage(
        in controller: ChatChannelController,
        text: String
    ) async throws -> MessageId {
        var lastError: Error = Self.error(
            "MiniCPM could not post its answer to this channel."
        )
        for attempt in 0..<3 {
            if attempt > 0 {
                try? await Task.sleep(for: .milliseconds(800))
            }
            do {
                try await synchronize(controller)
                return try await withCheckedThrowingContinuation { continuation in
                    controller.createNewMessage(text: text) { result in
                        continuation.resume(with: result)
                    }
                }
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private func synchronize(_ controller: ChatChannelController) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            controller.synchronize { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func error(_ message: String) -> Error {
        NSError(domain: "MiniCPMChat", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func finalizeBotMessage(
        _ controller: ChatMessageController,
        text: String
    ) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            controller.partialUpdateMessage(text: text) { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }
}
#endif
