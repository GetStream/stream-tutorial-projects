//
//  MatchChatView.swift
//  TrystMe
//
//  ISOLATED Stream Chat file (StreamChat + StreamChatSwiftUI).
//  A custom conversation built on the Chat state layer so we control the
//  composer and can hold circumvention/PII messages in a pending review state
//  before they're sent. Server-side blocklist + automod on the `tryst` channel
//  type provide a moderation backstop.
//

import SwiftUI
import Combine
import PhotosUI
import StreamChat
import StreamChatSwiftUI

@MainActor
final class ChatConversationModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = true

    private var chat: Chat?
    private var observation: Task<Void, Never>?
    let channelId: ChannelId

    init(channelId: ChannelId) { self.channelId = channelId }

    func load(client: ChatClient) async {
        let chat = client.makeChat(for: channelId)
        self.chat = chat
        try? await chat.get(watch: true)
        messages = chat.state.messages
        isLoading = false
        // Poll the state for new/updated messages (simple + reliable across SDK versions).
        observation = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 700_000_000)
                guard let self, let chat = self.chat else { return }
                let current = chat.state.messages
                if current.count != self.messages.count || current.first?.id != self.messages.first?.id {
                    self.messages = current
                }
            }
        }
    }

    func send(_ text: String, attachments: [AnyAttachmentPayload] = []) async {
        try? await chat?.sendMessage(with: text, attachments: attachments)
        if let chat { messages = chat.state.messages }
    }

    func toggleReaction(_ type: String, on message: ChatMessage) async {
        guard let chat else { return }
        let reaction = MessageReactionType(rawValue: type)
        let hasIt = message.currentUserReactions.contains { $0.type == reaction }
        if hasIt {
            try? await chat.deleteReaction(from: message.id, with: reaction)
        } else {
            try? await chat.sendReaction(to: message.id, with: reaction, enforceUnique: true)
        }
        messages = chat.state.messages
    }

    deinit { observation?.cancel() }
}

struct MatchChatView: View {
    let otherUserId: String
    let otherName: String
    let otherImage: String

    @EnvironmentObject private var appModel: AppModel
    @Injected(\.chatClient) private var chatClient
    @StateObject private var model: ChatConversationModel

    @State private var draft = ""
    @State private var heldFindings: [ModerationFinding] = []
    @State private var heldText = ""
    @State private var pickedItem: PhotosPickerItem?

    init(otherUserId: String, otherName: String, otherImage: String) {
        self.otherUserId = otherUserId
        self.otherName = otherName
        self.otherImage = otherImage
        _model = StateObject(wrappedValue: ChatConversationModel(
            channelId: ChatService.shared.channelId(with: otherUserId)
        ))
    }

    private var currentUserId: String { chatClient.currentUserId ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            if !heldFindings.isEmpty { moderationBanner }
            composer
        }
        .navigationTitle(otherName.split(separator: " ").first.map(String.init) ?? otherName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { appModel.startCall(withUserId: otherUserId, name: otherName, video: false) } label: {
                    Image(systemName: "phone.fill")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { appModel.startCall(withUserId: otherUserId, name: otherName, video: true) } label: {
                    Image(systemName: "video.fill")
                }
            }
        }
        .task { await model.load(client: chatClient) }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if model.isLoading { ProgressView().padding() }
                    ForEach(model.messages.reversed(), id: \.id) { message in
                        MessageBubble(
                            message: message,
                            isMine: message.author.id == currentUserId,
                            onReact: { type in Task { await model.toggleReaction(type, on: message) } }
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .onChange(of: model.messages.count) { _, _ in
                if let last = model.messages.reversed().last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var moderationBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Held for review", systemImage: "exclamationmark.shield.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.orange)
            Text("Sharing contact info, payments, or moving off TrystMe isn't allowed. Detected: \(heldFindings.map(\.category).joined(separator: ", ")).")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Edit message") {
                    draft = heldText
                    clearHeld()
                }
                .font(.caption.bold())
                Spacer()
                Button("Send anyway") {
                    let text = heldText
                    clearHeld()
                    Task { await model.send(text) }
                }
                .font(.caption.bold())
                .foregroundStyle(Brand.pink)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var composer: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $pickedItem, matching: .images) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Brand.pink)
                    .frame(width: 40, height: 40)
                    .background(Color(.secondarySystemBackground), in: Circle())
            }
            .onChange(of: pickedItem) { _, item in
                Task { await attach(item) }
            }

            TextField("Message \(otherName.split(separator: " ").first.map(String.init) ?? otherName)…",
                      text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22))

            Button { attemptSend() } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(draft.trimmingCharacters(in: .whitespaces).isEmpty ? AnyShapeStyle(Color.gray) : AnyShapeStyle(Brand.primaryGradient), in: Circle())
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func attach(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).jpg")
        do {
            try data.write(to: url)
            let payload = try AnyAttachmentPayload(localFileURL: url, attachmentType: .image)
            await model.send("", attachments: [payload])
        } catch {
            print("Attachment error: \(error)")
        }
        pickedItem = nil
    }

    private func attemptSend() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let findings = CircumventionGuard.scan(text)
        if findings.isEmpty {
            draft = ""
            Task { await model.send(text) }
        } else {
            // Hold the message in a pending review state instead of sending.
            withAnimation {
                heldText = text
                heldFindings = findings
            }
            draft = ""
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    private func clearHeld() {
        withAnimation { heldFindings = []; heldText = "" }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let isMine: Bool
    var onReact: (String) -> Void = { _ in }

    /// Available quick reactions: Stream type -> emoji.
    static let reactionOptions: [(type: String, emoji: String)] = [
        ("love", "❤️"), ("like", "👍"), ("haha", "😂"), ("wow", "😮"), ("sad", "😢")
    ]

    private static let emoji: [String: String] = Dictionary(
        uniqueKeysWithValues: reactionOptions.map { ($0.type, $0.emoji) }
    )

    private var sortedReactions: [(type: String, score: Int)] {
        message.reactionScores
            .map { (type: $0.key.rawValue, score: $0.value) }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
    }

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 50) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                bubble
                    .contextMenu { reactionMenu }
                if !sortedReactions.isEmpty { reactionBadges }
                Text(message.createdAt, style: .time)
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if !isMine { Spacer(minLength: 50) }
        }
    }

    @ViewBuilder
    private var bubble: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 6) {
            ForEach(message.imageAttachments, id: \.id) { attachment in
                AsyncImage(url: attachment.imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(.gray.opacity(0.2))
                }
                .frame(width: 200, height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            if !message.text.isEmpty {
                Text(message.text)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .foregroundStyle(isMine ? .white : .primary)
        .background {
            if isMine { Brand.primaryGradient } else { Color(.secondarySystemBackground) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var reactionMenu: some View {
        ForEach(Self.reactionOptions, id: \.type) { option in
            Button { onReact(option.type) } label: {
                Text("\(option.emoji)  \(option.type.capitalized)")
            }
        }
    }

    private var reactionBadges: some View {
        HStack(spacing: 4) {
            ForEach(sortedReactions, id: \.type) { reaction in
                let mine = message.currentUserReactions.contains { $0.type.rawValue == reaction.type }
                HStack(spacing: 2) {
                    Text(Self.emoji[reaction.type] ?? "❤️").font(.caption2)
                    Text("\(reaction.score)").font(.caption2.bold())
                }
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(mine ? Brand.pink.opacity(0.18) : Color(.tertiarySystemBackground), in: Capsule())
                .overlay(Capsule().stroke(mine ? Brand.pink.opacity(0.5) : .clear, lineWidth: 1))
            }
        }
    }
}
