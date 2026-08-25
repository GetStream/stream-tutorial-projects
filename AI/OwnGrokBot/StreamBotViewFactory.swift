#if os(iOS)
// StreamBotViewFactory.swift
// Where Stream's chat UI becomes StreamBot's.
//
// Only the parts that carry the product idea are overridden; everything else —
// reactions, threads, attachments, editing, read state, pagination — is the
// SDK's, and gets better with every SDK release without any work here.
//
// What is overridden, and why each one is necessary rather than cosmetic:
//
//   * Message text — routes run cards, streaming replies and routine receipts
//     to their own views. This is the whole interaction model; a run rendered as
//     plain text would just be a paragraph about a plan.
//   * Channel list item — a thread is a teammate, so the row shows the bot's
//     face, its lane, and whether it is working right now.
//   * Channel avatar — the bot's symbol on its accent, not initials in a circle.
//   * Channel header — who you are talking to and what they are allowed to do,
//     because the approval policy is the thing a user most needs to remember.
//   * Composer trailing — dictation lives next to send.
//   * Message actions — "Teach as routine" on any bot message, and Delete on
//     incoming messages the same way outgoing ones already can be deleted.
//     Deleted messages leave the thread instead of sitting as "Message deleted".

import StreamChat
import StreamChatSwiftUI
import SwiftUI

@MainActor
final class StreamBotViewFactory: ViewFactory {
    @Injected(\.chatClient) var chatClient

    static let shared = StreamBotViewFactory()
    private init() {}

    /// The floating, glass-backed composer and message styling the SDK ships
    /// for iOS 26+. Using the SDK's own Liquid Glass styles rather than
    /// re-implementing them keeps the composer consistent with the system
    /// keyboard and toolbar it sits between.
    var styles = LiquidGlassStyles()

    /// One composer view model per channel, shared with the dictation panel so
    /// speech can write straight into the draft the user is looking at.
    private var composerViewModels: [String: MessageComposerViewModel] = [:]

    // MARK: - Messages

    @ViewBuilder
    func makeMessageTextView(options: MessageTextViewOptions) -> some View {
        let message = options.message
        let bot = StreamBotRoster.shared.bot(id: message.author.id)

        switch StreamBotMessageKind.of(message) {
        case .run:
            if let run = message.streamBotRun, let bot {
                StreamBotRunCardView(
                    run: run,
                    bot: bot,
                    messageId: message.id,
                    cid: message.cid ?? ChannelId(type: .messaging, id: "unknown"),
                    isStreaming: message.streamBotIsStreaming
                )
            } else {
                defaultTextView(options)
            }

        case .reply:
            StreamBotReplyView(
                text: message.text,
                bot: bot,
                isStreaming: message.streamBotIsStreaming
            )

        case .routine:
            StreamBotRoutineNoteView(
                name: message.extraData["grok_routine_name"]?.stringValue ?? "Routine",
                detail: message.text,
                bot: bot
            )

        case .handoff:
            StreamBotHandoffView(
                text: message.text,
                from: bot,
                to: StreamBotRoster.shared.bot(
                    id: message.extraData["grok_handoff_to"]?.stringValue
                )
            )

        case .none:
            defaultTextView(options)
        }
    }

    @ViewBuilder
    private func defaultTextView(_ options: MessageTextViewOptions) -> some View {
        MessageTextView(
            factory: self,
            message: options.message,
            isFirst: options.isFirst,
            scrolledId: options.scrolledId,
            translationLanguage: options.translationLanguage
        )
    }

    // MARK: - Channel list

    /// Pins the factory's `ChannelDestination` associated type to a concrete
    /// type. Without this the type is only inferred from the SDK's default
    /// `makeChannelDestination`, and `makeChannelListItem` below — whose options
    /// are generic over it — then fails to match the protocol requirement and is
    /// silently ignored in favour of the SDK's own row.
    func makeChannelDestination(
        options: ChannelDestinationOptions
    ) -> @MainActor (ChannelSelectionInfo) -> StreamBotThreadScreen {
        { selection in StreamBotThreadScreen(selection: selection) }
    }

    func makeChannelListItem(
        options: ChannelListItemOptions<StreamBotThreadScreen>
    ) -> some View {
        let item = ChatChannelNavigatableListItem(
            channel: options.channel,
            channelListItem: StreamBotThreadRow(
                channel: options.channel,
                onTap: options.onItemTap
            ),
            channelDestination: options.channelDestination,
            selectedChannel: options.selectedChannel,
            handleTabBarVisibility: InjectedValues[\.utils]
                .messageListConfig.handleTabBarVisibility
        )
        // Wrapped exactly as the SDK does, so mute and delete still swipe in.
        return ChatChannelSwipeableListItem(
            factory: self,
            channelListItem: item,
            swipedChannelId: options.swipedChannelId,
            channel: options.channel,
            numberOfTrailingItems: 2,
            trailingRightButtonTapped: options.trailingSwipeRightButtonTapped,
            trailingLeftButtonTapped: options.trailingSwipeLeftButtonTapped,
            leadingSwipeButtonTapped: options.leadingSwipeButtonTapped
        )
    }

    func makeChannelAvatarView(options: ChannelAvatarViewOptions) -> some View {
        let channel = options.channel
        let bot = StreamBotRoster.shared.bot(id: channel.streamBotBotId)
        return StreamBotAvatar(
            symbolName: bot?.symbolName ?? channel.streamBotSymbolName,
            accent: bot?.color ?? channel.streamBotAccent.color,
            size: options.size,
            isWorking: StreamBotEngine.shared.isBusy(in: channel.cid)
        )
    }

    func makeEmptyChannelsView(options: EmptyChannelsViewOptions) -> some View {
        StreamBotEmptyState(
            symbolName: "person.2.badge.gearshape",
            title: "No teammates yet",
            detail: "Hire a bot and it gets its own thread. Ask it for something and watch it work."
        )
    }

    func makeChannelListBackground(options: ChannelListBackgroundOptions) -> some View {
        StreamBotBackdrop()
    }

    func makeMessageListBackground(options: MessageListBackgroundOptions) -> some View {
        StreamBotBackdrop()
    }

    func makeEmptyMessagesView(options: EmptyMessagesViewOptions) -> some View {
        StreamBotThreadIntroView(
            channel: options.channel,
            bot: StreamBotRoster.shared.bot(id: options.channel.streamBotBotId)
        )
    }

    /// Soft-deleted messages stay in Stream's local cache so the SDK can show a
    /// "Message deleted" placeholder. StreamBot treats delete as gone — no
    /// tombstone, no avatar, no timestamp.
    func makeDeletedMessageView(options: DeletedMessageViewOptions) -> some View {
        EmptyView()
    }

    @ViewBuilder
    func makeMessageItemView(options: MessageItemViewOptions) -> some View {
        if options.message.deletedAt != nil {
            EmptyView()
        } else {
            MessageItemView(
                factory: self,
                channel: options.channel,
                message: options.message,
                width: options.width,
                showsAllInfo: options.showsAllInfo,
                shownAsPreview: options.shownAsPreview,
                isInThread: options.isInThread,
                isLast: options.isLast,
                scrolledId: options.scrolledId,
                quotedMessage: options.quotedMessage,
                onLongPress: options.onLongPress,
                viewModel: options.viewModel
            )
        }
    }

    // MARK: - Channel header

    func makeChannelHeaderViewModifier(
        options: ChannelHeaderViewModifierOptions
    ) -> some ChatChannelHeaderViewModifier {
        StreamBotChannelHeaderModifier(channel: options.channel)
    }

    // MARK: - Composer

    func makeMessageComposerViewType(
        options: MessageComposerViewTypeOptions
    ) -> some View {
        let viewModel = composerViewModel(for: options)
        let channel = options.channelController.channel
        return VStack(spacing: 0) {
            if let cid = options.channelController.cid {
                StreamBotComposerAccessory(
                    cid: cid,
                    bot: StreamBotRoster.shared.bot(id: channel?.streamBotBotId),
                    composerViewModel: viewModel
                )
            }
            MessageComposerView(
                viewFactory: self,
                viewModel: viewModel,
                channelController: options.channelController,
                messageController: options.messageController,
                quotedMessage: options.quotedMessage,
                editedMessage: options.editedMessage,
                willSendMessage: options.willSendMessage
            )
        }
    }

    private func composerViewModel(
        for options: MessageComposerViewTypeOptions
    ) -> MessageComposerViewModel {
        let key = options.channelController.cid?.rawValue ?? "unknown-channel"
        if let existing = composerViewModels[key] { return existing }
        let viewModel = ViewModelsFactory.makeMessageComposerViewModel(
            with: options.channelController,
            messageController: options.messageController,
            quotedMessage: options.quotedMessage,
            editedMessage: options.editedMessage,
            willSendMessage: options.willSendMessage
        )
        composerViewModels[key] = viewModel
        return viewModel
    }

    // MARK: - Message actions

    func makeMessageActionsView(
        options: MessageActionsViewOptions
    ) -> some View {
        var actions = InjectedValues[\.utils].messageListConfig.supportedMessageActions(
            SupportedMessageActionsOptions(
                message: options.message,
                channel: options.channel,
                onFinish: options.onFinish,
                onError: options.onError
            )
        )
        if let teach = teachAction(for: options) {
            actions.insert(teach, at: 0)
        }
        if let delete = deleteIncomingAction(for: options, existing: actions) {
            actions.append(delete)
        }
        return MessageActionsView(messageActions: actions)
    }

    /// "Teach as routine", offered on a bot's message.
    ///
    /// Anchored to a message rather than sitting in the header because teaching
    /// is about a specific exchange that went well — the user points at the
    /// result they liked and the bot reads the thread that produced it.
    private func teachAction(for options: MessageActionsViewOptions) -> MessageAction? {
        let message = options.message
        guard !message.isSentByCurrentUser,
              message.deletedAt == nil,
              let bot = StreamBotRoster.shared.bot(id: message.author.id) else {
            return nil
        }
        let channel = options.channel
        let onFinish = options.onFinish
        return MessageAction(
            id: "streamBotTeachRoutine",
            title: "Teach as routine",
            iconName: "graduationcap",
            action: {
                onFinish(MessageActionInfo(message: message, identifier: "streamBotTeachRoutine"))
                StreamBotTeachCoordinator.shared.teach(bot: bot, in: channel.cid)
            },
            confirmationPopup: nil,
            isDestructive: false
        )
    }

    /// Delete on a bot's message, matching the outgoing Delete control.
    ///
    /// The SDK only offers delete on incoming messages when the channel allows
    /// `delete-any-message`. StreamBot's incoming messages are authored by bots,
    /// so that capability is off and the action never appears. The bot still
    /// owns the message, and we already have a client authenticated as that bot,
    /// so the delete is issued as the author — the same permission model as
    /// deleting your own outgoing message.
    private func deleteIncomingAction(
        for options: MessageActionsViewOptions,
        existing actions: [MessageAction]
    ) -> MessageAction? {
        let message = options.message
        guard !message.isSentByCurrentUser,
              message.deletedAt == nil,
              !actions.contains(where: { $0.id == MessageActionId.delete }) else {
            return nil
        }

        let cid = options.channel.cid
        let authorId = message.author.id
        let onFinish = options.onFinish
        let onError = options.onError
        let isStreaming = message.extraData["grok_streaming"]?.boolValue ?? false

        return MessageAction(
            id: MessageActionId.delete,
            title: "Delete",
            iconName: "trash",
            action: {
                if isStreaming {
                    StreamBotEngine.shared.cancel(in: cid)
                }
                Task {
                    do {
                        if StreamBotSender.shared.canSpeak(botId: authorId) {
                            try await StreamBotSender.shared.delete(
                                botId: authorId,
                                messageId: message.id,
                                in: cid
                            )
                        } else if let client = StreamBotChatService.shared.chatClient {
                            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                                client.messageController(cid: cid, messageId: message.id)
                                    .deleteMessage { error in
                                        if let error {
                                            continuation.resume(throwing: error)
                                        } else {
                                            continuation.resume()
                                        }
                                    }
                            }
                        } else {
                            throw StreamBotError("Could not delete this message.")
                        }
                        onFinish(MessageActionInfo(message: message, identifier: MessageActionId.delete))
                    } catch {
                        onError(error)
                    }
                }
            },
            confirmationPopup: ConfirmationPopup(
                title: "Delete Message",
                message: "Are you sure you want to permanently delete this message?",
                buttonTitle: "Delete"
            ),
            isDestructive: true
        )
    }
}

// MARK: - Thread intro

/// What a thread shows before anything has been said in it.
///
/// A blank message list is the worst possible first impression for a teammate
/// whose abilities are invisible: the user has to guess what to ask. This states
/// the bot's charter, where it works, and — most importantly — whether it will
/// act on its own or wait for approval, which is the one thing that changes how
/// carefully the first request should be worded.
struct StreamBotThreadIntroView: View {
    let channel: ChatChannel
    let bot: StreamBotTeammate?

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)

            StreamBotAvatar(
                symbolName: bot?.symbolName ?? channel.streamBotSymbolName,
                accent: bot?.color ?? channel.streamBotAccent.color,
                size: 68
            )

            VStack(spacing: 5) {
                Text(bot?.shortName ?? channel.streamBotTitle)
                    .font(.title2.weight(.semibold))
                Text(bot?.roleName ?? channel.streamBotLane?.title ?? "Team thread")
                    .font(.subheadline)
                    .foregroundStyle(.streamBotSecondary)
            }

            if let bot {
                StreamBotCard(tint: bot.color) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ask me to \(bot.lane.charter).")
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider().opacity(0.5)

                        Label(bot.approval.title, systemImage: bot.approval.symbolName)
                            .font(.caption.weight(.medium))
                            .streamBotAccentText(bot.color)
                            .streamBotRepeatingSymbolEffect(for: bot.approval.symbolName)
                        Text(bot.approval.detail)
                            .font(.caption)
                            .foregroundStyle(.streamBotSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if !bot.workspaces.isEmpty {
                            // Declared surfaces, not connected accounts — the
                            // wording matters, because the bot plans against
                            // these without having credentials for any of them.
                            Text("Plans against")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.streamBotSecondary)
                            HStack(spacing: 6) {
                                ForEach(bot.workspaces) { workspace in
                                    StreamBotPill(
                                        text: workspace.title,
                                        symbolName: workspace.symbolName
                                    )
                                }
                            }
                        }
                    }
                }
            } else if channel.streamBotIsRoom {
                StreamBotCard {
                    Text("Everyone's here. Mention a teammate to hand them something, or just ask — \(StreamBotRoster.shared.bot(id: channel.streamBotLeadBotId)?.shortName ?? "the lead") picks who takes it.")
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Thread screen

/// A thread, with the tab bar out of the way.
///
/// Wrapping `ChatChannelView` rather than returning it directly is what lets the
/// tab bar be hidden while a thread is open — the composer and the glass tab bar
/// otherwise land on the same strip of screen. It also gives the factory's
/// `ChannelDestination` a concrete type, which the channel list row override
/// depends on.
struct StreamBotThreadScreen: View {
    let selection: ChannelSelectionInfo

    @Injected(\.chatClient) private var chatClient

    var body: some View {
        let controller = chatClient.channelController(for: selection.channel.cid)
        ChatChannelView(
            viewFactory: StreamBotViewFactory.shared,
            viewModel: StreamBotChannelViewModel(
                channelController: controller,
                scrollToMessage: selection.message
            ),
            channelController: controller,
            scrollToMessage: selection.message
        )
        .toolbar(.hidden, for: .tabBar)
    }
}

/// Drops deleted messages from the thread so grouping, avatars, and dates
/// behave as if the message was never there — not as an empty cell.
@MainActor
final class StreamBotChannelViewModel: ChatChannelViewModel {
    override func groupMessages() {
        let visible = messages.filter { $0.deletedAt == nil }
        if visible.count != messages.count {
            messages = visible
            return
        }
        super.groupMessages()
    }
}

// MARK: - Thread row

/// A channel row that reads as a teammate.
///
/// The SDK's default row is built for people: avatar, name, last message,
/// unread badge. That is nearly right, but it buries the two things that matter
/// here — which lane the bot works in, and whether it is doing something right
/// now — so the row is rebuilt with those promoted.
struct StreamBotThreadRow: View {
    let channel: ChatChannel
    let onTap: (ChatChannel) -> Void

    private var bot: StreamBotTeammate? { StreamBotRoster.shared.bot(id: channel.streamBotBotId) }
    private var accent: Color { bot?.color ?? channel.streamBotAccent.color }
    private var phase: StreamBotEngine.Phase { StreamBotEngine.shared.phase(in: channel.cid) }
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            onTap(channel)
        } label: {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    StreamBotAvatar(
                        symbolName: bot?.symbolName ?? channel.streamBotSymbolName,
                        accent: accent,
                        size: 46,
                        isWorking: phase.isBusy
                    )
                    StreamBotStatusDot(activity: activity)
                        .offset(x: 2, y: 2)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(bot?.shortName ?? channel.streamBotTitle)
                            .font(.headline)
                            .lineLimit(1)
                        if let lane = bot?.lane ?? channel.streamBotLane {
                            StreamBotPill(text: lane.title, tint: accent, isProminent: true)
                        }
                        Spacer(minLength: 0)
                        if channel.unreadCount.messages > 0 {
                            Text("\(channel.unreadCount.messages)")
                                .font(.caption2.weight(.bold).monospacedDigit())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .frame(height: 18)
                                .background(accent, in: .capsule)
                        } else if phase == .awaitingApproval {
                            StreamBotPill(text: "Needs you", tint: .orange, isProminent: true)
                        }
                    }
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(phase.isBusy || phase == .awaitingApproval
                            ? accent.streamBotOnGlass(in: colorScheme)
                            : .streamBotSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var activity: StreamBotStatusDot.Activity {
        switch phase {
        case .idle: .idle
        case .planning, .working, .replying: .working
        case .awaitingApproval: .waiting
        case .failed: .failed
        }
    }

    /// What the bot is doing beats what it last said. A row that reads
    /// "Drafting the reply" is more useful than the first line of a draft the
    /// user is about to be shown anyway.
    private var subtitle: String {
        if let label = phase.shortLabel { return label }
        if let preview = channel.latestMessages.first(where: { $0.deletedAt == nil })?.text,
           !preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return preview
        }
        return bot?.tagline ?? "Ready"
    }
}

// MARK: - Header

/// Channel header: the teammate, its lane, and its approval policy — plus a way
/// into everything it knows.
struct StreamBotChannelHeaderModifier: ChatChannelHeaderViewModifier {
    var channel: ChatChannel

    @State private var showsDetail = false

    private var bot: StreamBotTeammate? { StreamBotRoster.shared.bot(id: channel.streamBotBotId) }

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text(bot?.shortName ?? channel.streamBotTitle)
                            .font(.headline)
                        HStack(spacing: 4) {
                            if let bot {
                                Image(systemName: bot.approval.symbolName)
                                    .font(.system(size: 8, weight: .bold))
                                    .streamBotRepeatingSymbolEffect(for: bot.approval.symbolName)
                                Text(bot.approval.title)
                            } else {
                                Text(channel.streamBotLane?.title ?? "Team room")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.streamBotSecondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    StreamBotRoundButton(
                        symbolName: "slider.horizontal.3",
                        accessibilityLabel: "Bot settings",
                        size: .small
                    ) {
                        showsDetail = true
                    }
                    .disabled(bot == nil)
                }
            }
            .sheet(isPresented: $showsDetail) {
                if let bot {
                    StreamBotDetailView(bot: bot, cid: channel.cid)
                }
            }
    }
}

// MARK: - Handoff

/// One bot passing work to another, shown as a line rather than a bubble so a
/// room's routing reads as movement instead of conversation.
struct StreamBotHandoffView: View {
    let text: String
    let from: StreamBotTeammate?
    let to: StreamBotTeammate?

    var body: some View {
        HStack(spacing: 8) {
            if let from {
                StreamBotAvatar(symbolName: from.symbolName, accent: from.color, size: 22)
            }
            Image(systemName: "arrow.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.streamBotSecondary)
                .streamBotRepeatingSymbolEffect(for: "arrow.right")
            if let to {
                StreamBotAvatar(symbolName: to.symbolName, accent: to.color, size: 22)
            }
            Text(text)
                .font(.caption)
                .foregroundStyle(.streamBotSecondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassEffect(.regular, in: .capsule)
    }
}
#endif
