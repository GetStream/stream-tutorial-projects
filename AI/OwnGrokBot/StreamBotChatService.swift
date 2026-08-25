#if os(iOS)
// StreamBotChatService.swift
// Stream wiring for StreamBot: the user's own client, and the per-bot clients
// that let a teammate speak in its own voice.
//
// Why two kinds of client:
//
// A bot reply has to arrive as an *incoming* message from that bot — with the
// bot's name, its avatar, its colour, on the left of the thread — or the whole
// "teammate" idea collapses into the user talking to themselves. Stream models
// that correctly: the message is authored by the bot user. Doing it from the
// device therefore needs a connection authenticated as the bot, which is what
// `StreamBotSender` owns. The alternative — a server-side send with the API
// secret — is not available to an app that ships no backend, and the secret
// must never be in the bundle.
//
// The bot clients are deliberately thin: local storage off (they never render a
// message list, and a second client writing the same store would fight the
// user's client over it), and only as many kept connected as the conversation
// actually needs.

import Foundation
import StreamChat
import StreamChatSwiftUI
import SwiftUI

// MARK: - Credentials

/// Stream credentials for this demo.
///
/// The API key is public by design. The tokens are CLI-minted user JWTs — never
/// the API secret, which stays server-side. Bot tokens are what let each
/// teammate author its own messages from the device.
enum StreamBotCredentials {
    static let apiKey = "4dz7gst7phy5"

    static let userId = "amos"
    static let userName = "Amos Gyamfi"
    static let userToken =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE3ODMwMTAyOTEsInVzZXJfaWQiOiJhbW9zIn0.nh8-jdEHgloLXjhCzem-qtxcNILAk-a_5uBOHEl1KZk"

    /// Never-expiring tokens for the seeded teammates.
    static let botTokens: [String: String] = [
        "grok-sales":
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE3ODY2MDM3ODQsInVzZXJfaWQiOiJncm9rLXNhbGVzIn0.HJeQ8MCuP9C-4rr_nmqmTUk1qVVTo6oLB_A3CbgWg2I",
        "grok-talent":
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE3ODY2MDM3ODQsInVzZXJfaWQiOiJncm9rLXRhbGVudCJ9.xsRxQwb55JxCgkUi3WapYuG9aZ3eJRuhY6LeeejPiD4",
        "grok-inbox":
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE3ODY2MDM3ODQsInVzZXJfaWQiOiJncm9rLWluYm94In0.LSVRrCT_606HSeex1cFbNmUr1-_bp97K_i88urYT3iU",
        "grok-expense":
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE3ODY2MDM3ODQsInVzZXJfaWQiOiJncm9rLWV4cGVuc2UifQ.LwOIIH3fmoqbSKFZGihuDkiiGc3PalDRbhE9GgpGH_c",
        "grok-invoice":
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE3ODY2MDM3ODQsInVzZXJfaWQiOiJncm9rLWludm9pY2UifQ.8onWS6-f4Zm5KRAEHoCg0gkl3t4kDBkHas-ElsDQ94c",
        "grok-account":
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE3ODY2MDM3ODQsInVzZXJfaWQiOiJncm9rLWFjY291bnQifQ.P5fiv_SbzXfRoDKZEoZ3ADEA7QBOPXdC-kTLhwFKnok",
        "grok-bugs":
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE3ODY2MDM3ODQsInVzZXJfaWQiOiJncm9rLWJ1Z3MifQ.3r4QvxawCsnZMopmk5B0ZOd2nHVot13KLGYqQUgaIpc",
        "grok-compete":
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE3ODY2MDM3ODQsInVzZXJfaWQiOiJncm9rLWNvbXBldGUifQ.LWCMCJbheyC-RctI85VLVS58ZPprz4XlTSj1zLH4bQU",
        "grok-nova":
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE3ODY2MDYzNjAsInVzZXJfaWQiOiJncm9rLW5vdmEifQ.5vuQuMeGuWCrAnKUhi7OMY_LEv-cR-RpGkb69c9fQFw"
    ]
}

// MARK: - Service

@MainActor
final class StreamBotChatService {
    static let shared = StreamBotChatService()

    private(set) var streamChat: StreamChat?
    private(set) var chatClient: ChatClient?

    private init() {}

    /// Creates the client and connects the user. Called from the root view's
    /// initialiser so no Stream view can render before it has run.
    func setUpIfNeeded() {
        guard streamChat == nil else { return }

        var config = ChatClientConfig(apiKey: .init(StreamBotCredentials.apiKey))
        config.isLocalStorageEnabled = true
        config.staysConnectedInBackground = true

        let client = ChatClient(config: config)
        chatClient = client
        streamChat = StreamChat(
            chatClient: client,
            appearance: StreamBotAppearance.make(),
            utils: Utils(
                // The SDK's hold-to-record mic sends an audio *attachment*; the
                // mic in the accessory strip dictates into the draft. Two mics an
                // inch apart doing different things is a coin flip for the user,
                // so the recorder is off and dictation owns the gesture.
                composerConfig: ComposerConfig(isVoiceRecordingEnabled: false)
            )
        )

        client.connectUser(
            userInfo: UserInfo(
                id: StreamBotCredentials.userId,
                name: StreamBotCredentials.userName,
                imageURL: nil
            ),
            token: Token(stringLiteral: StreamBotCredentials.userToken)
        ) { error in
            if let error {
                print("StreamBot — Stream connect failed: \(error)")
            }
        }
    }

    /// The query behind the Chats tab.
    ///
    /// The app shares a Stream app with other demos, so filtering on members
    /// alone would pull in unrelated channels. Every StreamBot channel carries
    /// `bot_app: "owngrokbot"` in its custom data, and that marker is what
    /// scopes the list.
    var channelListQuery: ChannelListQuery {
        ChannelListQuery(
            filter: .and([
                .containMembers(userIds: [StreamBotCredentials.userId]),
                .equal("bot_app", to: StreamBotTeammate.appMarker)
            ]),
            sort: [.init(key: .lastMessageAt, isAscending: false)],
            pageSize: 30
        )
    }

    /// Creates the thread for a newly made bot. The channel carries the same
    /// marker and bot pointer the seeded ones do, so it appears in the list and
    /// resolves back to its bot without extra bookkeeping.
    func createThread(for bot: StreamBotTeammate) throws -> ChatChannelController {
        guard let chatClient else {
            throw StreamBotError("Stream client is not ready yet.")
        }
        let controller = try chatClient.channelController(
            createChannelWithId: bot.threadChannelId,
            name: bot.roleName,
            members: [StreamBotCredentials.userId, bot.id],
            extraData: [
                "name": .string(bot.roleName),
                "bot_app": .string(StreamBotTeammate.appMarker),
                "bot_id": .string(bot.id),
                "symbol": .string(bot.symbolName),
                "accent": .string(bot.accent.rawValue),
                "lane": .string(bot.lane.rawValue)
            ]
        )
        controller.synchronize()
        return controller
    }
}

// MARK: - Channel helpers

extension StreamBotTeammate {
    /// The channel holding this bot's one-to-one thread.
    ///
    /// Derived rather than looked up so any screen can address a bot's thread
    /// without first loading the channel list — the roster grid needs it just to
    /// know whether a bot is mid-run.
    ///
    /// The `grok-` prefix is dropped because bot ids and channel ids were seeded
    /// as `grok-sales` / `grokbot-sales`, and this is the one place that
    /// difference is allowed to exist.
    var threadChannelId: ChannelId {
        let stem = id.hasPrefix("grok-") ? String(id.dropFirst("grok-".count)) : id
        return ChannelId(type: .messaging, id: "grokbot-\(stem)")
    }
}

extension ChatChannel {
    /// The teammate this thread belongs to, when it is a one-to-one bot thread.
    var streamBotBotId: String? { extraData["bot_id"]?.stringValue }

    /// In a room, the teammate that takes anything not addressed to someone
    /// specific and routes it.
    var streamBotLeadBotId: String? { extraData["lead_bot"]?.stringValue }

    /// True for the multi-bot rooms, where several teammates and the user share
    /// one thread and work is passed between them.
    var streamBotIsRoom: Bool { extraData["is_room"]?.boolValue ?? false }

    var streamBotAccent: StreamBotAccent { StreamBotAccent(name: extraData["accent"]?.stringValue) }

    var streamBotSymbolName: String { extraData["symbol"]?.stringValue ?? "sparkles" }

    var streamBotLane: StreamBotLane? {
        extraData["lane"]?.stringValue.flatMap(StreamBotLane.init(rawValue:))
    }

    var streamBotTitle: String { name ?? extraData["name"]?.stringValue ?? cid.id }
}

// MARK: - Bot senders

/// Owns the connections that let bots speak.
///
/// Clients are created on first use and the least recently used one is dropped
/// once the cap is reached, because each is a live websocket and a user with a
/// dozen teammates should not be holding a dozen sockets open to watch two of
/// them work.
@MainActor
final class StreamBotSender {
    static let shared = StreamBotSender()

    private struct Connection {
        let client: ChatClient
        var lastUsed: Date
    }

    private var connections: [String: Connection] = [:]
    private var controllers: [String: ChatChannelController] = [:]
    private var messageControllers: [String: ChatMessageController] = [:]
    private var messageControllerKeys: [String] = []
    /// The last queued write per message, so the next one can wait for it.
    private var editQueue: [String: Task<Void, Error>] = [:]
    private static let maxConnections = 4
    private static let maxMessageControllers = 12

    private init() {}

    /// Whether this bot can author messages. Bots created in-app have no minted
    /// token, so they fall back to being narrated by the runtime instead.
    func canSpeak(botId: String) -> Bool {
        StreamBotCredentials.botTokens[botId] != nil
    }

    // MARK: Sending

    /// Posts a message as `botId` and returns its id, so the caller can keep
    /// editing it while the model streams.
    func send(
        botId: String,
        in cid: ChannelId,
        text: String,
        extraData: [String: RawJSON]
    ) async throws -> MessageId {
        let controller = try await controller(botId: botId, cid: cid)
        return try await withCheckedThrowingContinuation { continuation in
            controller.createNewMessage(
                text: text,
                extraData: extraData
            ) { result in
                continuation.resume(with: result)
            }
        }
    }

    /// Rewrites a message the bot already sent. This is how streaming reaches
    /// the thread: the first token creates the message, every later chunk edits
    /// it, and the final edit clears the streaming flag.
    ///
    /// Two things keep a token stream from tripping over itself. Edits to one
    /// message are queued, so a write never starts while the previous one is
    /// still going out; and because `editMessage`'s completion fires when the
    /// local write lands rather than when the API call returns, the queue is not
    /// enough on its own — each write also waits for the message to leave the
    /// state the SDK refuses to edit in.
    func edit(
        botId: String,
        messageId: MessageId,
        in cid: ChannelId,
        text: String,
        extraData: [String: RawJSON]
    ) async throws {
        let key = "\(botId)|\(messageId)"
        let previous = editQueue[key]
        let write = Task { [weak self] in
            // `result`, not `value`: a failed write must not cancel the one
            // behind it, which is usually the more recent state anyway.
            _ = await previous?.result
            guard let self else { return }
            let controller = try await messageController(
                botId: botId,
                cid: cid,
                messageId: messageId
            )
            try await Self.write(
                text: text,
                extraData: extraData,
                through: controller
            )
        }
        editQueue[key] = write
        defer { if editQueue[key] == write { editQueue[key] = nil } }
        try await write.value
    }

    private static func write(
        text: String,
        extraData: [String: RawJSON],
        through controller: ChatMessageController
    ) async throws {
        for attempt in 1...3 {
            await waitUntilEditable(controller)
            do {
                return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    controller.editMessage(
                        text: text,
                        skipEnrichUrl: true,
                        skipPush: true,
                        extraData: extraData
                    ) { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
            } catch {
                guard attempt < 3, isMidFlight(error) else { throw error }
                try? await Task.sleep(for: .milliseconds(350))
            }
        }
    }

    /// Waits out a write that is still on the wire.
    ///
    /// The SDK rejects an edit to a message it is currently sending or syncing.
    /// That window is short, so waiting for it beats surfacing a failure the
    /// user can do nothing about.
    private static func waitUntilEditable(_ controller: ChatMessageController) async {
        for _ in 0..<20 {
            switch controller.message?.localState {
            case .sending, .syncing, .deleting:
                try? await Task.sleep(for: .milliseconds(150))
            default:
                return
            }
        }
    }

    /// Whether this is the SDK refusing an edit because the message is busy.
    ///
    /// `ClientError.MessageEditing` is internal to StreamChat, so the only way
    /// to recognise it is by name. It is worth recognising: it means "ask again
    /// in a moment", where every other failure here means something real.
    private static func isMidFlight(_ error: Error) -> Bool {
        String(describing: type(of: error)) == "MessageEditing"
    }

    /// Shows the bot as typing while it thinks. Stream expires typing state on
    /// its own, so this is called repeatedly rather than paired with a stop.
    func startTyping(botId: String, in cid: ChannelId) async {
        guard let controller = try? await controller(botId: botId, cid: cid) else { return }
        controller.sendKeystrokeEvent()
    }

    func stopTyping(botId: String, in cid: ChannelId) async {
        guard let controller = try? await controller(botId: botId, cid: cid) else { return }
        controller.sendStopTypingEvent()
    }

    /// Soft-deletes a message the bot authored. Incoming bot messages are not
    /// the current user's, so the SDK's own-message delete never appears; this
    /// is the same delete, issued as the author.
    func delete(botId: String, messageId: MessageId, in cid: ChannelId) async throws {
        let controller = try await messageController(
            botId: botId,
            cid: cid,
            messageId: messageId
        )
        await Self.waitUntilEditable(controller)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            controller.deleteMessage { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Adds a reaction as the bot — used to acknowledge the user's message the
    /// moment work starts, before there is anything to say.
    func acknowledge(botId: String, messageId: MessageId, in cid: ChannelId) async {
        guard let client = try? await client(botId: botId) else { return }
        client.messageController(cid: cid, messageId: messageId)
            .addReaction("eyes", enforceUnique: true)
    }

    // MARK: Profile

    /// Writes an edited bot back to Stream.
    ///
    /// A client may only update the user it is authenticated as, so the bot
    /// updates itself through its own connection. That is the only route
    /// available without a backend — and it is the right one: it keeps the roster
    /// in Stream as the single source of truth, so a policy changed on the phone
    /// is the policy the iPad sees.
    func updateProfile(_ bot: StreamBotTeammate) async throws {
        guard let client = try await client(botId: bot.id) else {
            throw StreamBotError("\(bot.shortName) has no token, so its profile cannot be changed.")
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            client.currentUserController().updateUserData(
                name: bot.name,
                userExtraData: bot.streamExtraData
            ) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: Connections

    /// A synchronised controller for one of the bot's own messages.
    ///
    /// Synchronising first is what makes an edit land: these clients keep no
    /// local store, so a controller made on the spot may not have the message
    /// yet and the edit is rejected. Streaming rewrites the same message many
    /// times, so the controller is kept — the round trip happens once per
    /// message, not once per token.
    private func messageController(
        botId: String,
        cid: ChannelId,
        messageId: MessageId
    ) async throws -> ChatMessageController {
        let key = "\(botId)|\(messageId)"
        if let existing = messageControllers[key] { return existing }
        guard let client = try await client(botId: botId) else {
            throw StreamBotError("\(botId) has no token and cannot edit its messages.")
        }
        let controller = client.messageController(cid: cid, messageId: messageId)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            controller.synchronize { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        messageControllerKeys.append(key)
        messageControllers[key] = controller
        // Oldest first: a thread scrolled through for an hour would otherwise
        // accumulate a controller per message the bots ever streamed.
        while messageControllerKeys.count > Self.maxMessageControllers {
            messageControllers[messageControllerKeys.removeFirst()] = nil
        }
        return controller
    }

    private func controller(botId: String, cid: ChannelId) async throws -> ChatChannelController {
        let key = "\(botId)|\(cid.rawValue)"
        if let existing = controllers[key] { return existing }
        guard let client = try await client(botId: botId) else {
            throw StreamBotError("\(botId) has no token and cannot post messages.")
        }
        let controller = client.channelController(for: cid)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            controller.synchronize { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        controllers[key] = controller
        return controller
    }

    private func client(botId: String) async throws -> ChatClient? {
        if var connection = connections[botId] {
            connection.lastUsed = Date()
            connections[botId] = connection
            return connection.client
        }
        guard let token = StreamBotCredentials.botTokens[botId] else { return nil }

        evictIfNeeded()

        // Local storage stays off: these clients only write. Two clients sharing
        // the on-disk store would race the user's client over the same records.
        var config = ChatClientConfig(apiKey: .init(StreamBotCredentials.apiKey))
        config.isLocalStorageEnabled = false
        config.isClientInActiveMode = true

        let client = ChatClient(config: config)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            client.connectUser(
                userInfo: UserInfo(id: botId),
                token: Token(stringLiteral: token)
            ) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        connections[botId] = Connection(client: client, lastUsed: Date())
        return client
    }

    private func evictIfNeeded() {
        guard connections.count >= Self.maxConnections,
              let oldest = connections.min(by: { $0.value.lastUsed < $1.value.lastUsed })?.key else {
            return
        }
        connections[oldest]?.client.logout {}
        connections[oldest] = nil
        controllers = controllers.filter { !$0.key.hasPrefix("\(oldest)|") }
        messageControllers = messageControllers.filter { !$0.key.hasPrefix("\(oldest)|") }
        messageControllerKeys.removeAll { $0.hasPrefix("\(oldest)|") }
        editQueue = editQueue.filter { !$0.key.hasPrefix("\(oldest)|") }
    }
}

// MARK: - Error

struct StreamBotError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
#endif
