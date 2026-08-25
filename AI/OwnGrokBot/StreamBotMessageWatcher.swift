#if os(iOS)
// StreamBotMessageWatcher.swift
// What makes a bot answer.
//
// The obvious place to trigger a reply is the composer's send callback. This
// listens to Stream's event stream instead, and that difference matters:
//
//   * A message sent from another device still gets answered. Hooking the
//     composer only reacts to typing that happened on this screen.
//   * The bot gets the real message id, so it can react to the user's message
//     while it works.
//   * Rooms work without special casing. The same rule — "a message arrived,
//     decide who it is for" — covers a one-to-one thread and a room with five
//     teammates in it.
//
// Every reply is a side effect of a message existing, which is exactly what a
// bot is.

import Foundation
import StreamChat

@MainActor
final class StreamBotMessageWatcher: NSObject, EventsControllerDelegate {
    static let shared = StreamBotMessageWatcher()

    private var controller: EventsController?

    /// Messages already handled. The event stream can deliver the same message
    /// twice — once optimistically as it is sent, once when the socket echoes it
    /// back — and a bot that plans the same request twice is unforgivable.
    private var handled: Set<MessageId> = []

    private override init() { super.init() }

    func start() {
        guard controller == nil, let client = StreamBotChatService.shared.chatClient else { return }
        let controller = client.eventsController()
        controller.delegate = self
        self.controller = controller
    }

    func eventsController(_ controller: EventsController, didReceiveEvent event: Event) {
        guard let event = event as? MessageNewEvent else { return }
        handle(event)
    }

    private func handle(_ event: MessageNewEvent) {
        // Only the user's own messages, only in this app's channels, only plain
        // text. A bot's own output arriving back over the socket must never
        // start another run.
        guard event.user.id == StreamBotCredentials.userId,
              event.channel.extraData["bot_app"]?.stringValue == StreamBotTeammate.appMarker,
              StreamBotMessageKind.of(event.message) == nil,
              !handled.contains(event.message.id) else {
            return
        }

        let text = event.message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let roster = StreamBotRoster.shared
        let channel = event.channel

        // A one-to-one thread names its bot in the channel's custom data, so
        // there is nothing to work out.
        if let bot = roster.bot(id: channel.streamBotBotId) {
            markHandled(event.message.id)
            StreamBotEngine.shared.start(
                request: text,
                userMessageId: event.message.id,
                bot: bot,
                in: event.cid
            )
            return
        }

        // A room. The user either named someone, or the lead routes it.
        let members = channel.lastActiveMembers.compactMap { roster.bot(id: $0.id) }
        guard !members.isEmpty else { return }
        markHandled(event.message.id)

        if let mentioned = Self.mentionedBot(in: text, among: members) {
            StreamBotEngine.shared.start(
                request: text,
                userMessageId: event.message.id,
                bot: mentioned,
                in: event.cid
            )
            return
        }

        let lead = roster.bot(id: channel.streamBotLeadBotId)
            ?? members.first { $0.lane == .coordination }
            ?? members[0]
        StreamBotEngine.shared.route(
            request: text,
            userMessageId: event.message.id,
            lead: lead,
            candidates: members.filter { $0.id != lead.id },
            in: event.cid
        )
    }

    private func markHandled(_ id: MessageId) {
        handled.insert(id)
        if handled.count > 200 {
            handled.removeFirst()
        }
    }

    /// Matches a leading or embedded `@Name` against the room's teammates.
    private static func mentionedBot(in text: String, among bots: [StreamBotTeammate]) -> StreamBotTeammate? {
        guard text.contains("@") else { return nil }
        let lowered = text.lowercased()
        // Longest name first, so "@Ada Lovelace" does not match a bot called
        // "@Ada" when both are in the room.
        return bots
            .sorted { $0.shortName.count > $1.shortName.count }
            .first { lowered.contains("@\($0.shortName.lowercased())") }
    }
}
#endif
