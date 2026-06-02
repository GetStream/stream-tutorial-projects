//
//  InboxTabHost.swift
//  OOMarketplace
//
//  File isolation: this file (and everything Chat-related) imports StreamChat +
//  StreamChatSwiftUI only. Never import StreamVideoSwiftUI or StreamFeeds here.
//

import Combine
import SwiftUI
import StreamChat
import StreamChatSwiftUI

// MARK: - Tab host

struct InboxTabHost: View {
    /// Owned so we can write `selectedChannel` directly when a deep-link arrives.
    /// `selectedChannelId` is only consulted at first render, so it cannot drive
    /// deep-links posted later in the app's lifetime.
    @StateObject private var viewModel: ChatChannelListViewModel = {
        ViewModelsFactory.makeChannelListViewModel(
            channelListController: nil,
            selectedChannelId: nil,
            searchType: .messages
        )
    }()

    @State private var deepLinkCancellable: AnyCancellable?

    var body: some View {
        ChatChannelListView(
            viewFactory: OOChatFactory.shared,
            viewModel: viewModel,
            title: "Inbox"
        )
        .onReceive(NotificationCenter.default.publisher(for: AppEvents.openChat)) { note in
            guard let req = note.object as? OpenChatRequest else { return }
            openChannel(bareId: req.channelId)
        }
        .onReceive(NotificationCenter.default.publisher(for: AppEvents.reportUser)) { note in
            if let req = note.object as? ReportUserRequest, req.context == "chat" {
                ChatService.shared.muteUser(req.userId)
            }
        }
    }

    // MARK: - Deep-link resolver

    /// Reactively selects a channel by bare ID (e.g. `"listing-airpods"`).
    /// Works whether the channel is already loaded or needs to be fetched
    /// from the server. Writing `viewModel.selectedChannel` triggers the
    /// `ChatChannelListView`'s NavigationLink to push the channel detail.
    private func openChannel(bareId: String) {
        let cid = ChannelId(type: .messaging, id: bareId)

        if let channel = viewModel.channels.first(where: { $0.cid == cid }) {
            viewModel.selectedChannel = channel.channelSelectionInfo
            return
        }

        // Channel not loaded yet - wait for the next channel-list refresh.
        deepLinkCancellable = viewModel.$channels
            .compactMap { $0.first(where: { $0.cid == cid }) }
            .first()
            .map(\.channelSelectionInfo)
            .sink { [weak viewModel] selection in
                viewModel?.selectedChannel = selection
            }

        // Also kick a synchronize so a brand-new channel shows up in the list.
        if let client = ChatService.shared.chatClient {
            let controller = client.channelController(for: cid)
            controller.synchronize { _ in }
        }
    }
}

// MARK: - Custom ViewFactory: listing-aware channel header + report action

final class OOChatFactory: ViewFactory {
    @Injected(\.chatClient) public var chatClient
    public var styles = RegularStyles()
    public static let shared = OOChatFactory()
    private init() {}

    /// Replaces the channel-detail navigation bar with a listing-aware header:
    /// title + price, plus phone / video / report controls.
    public func makeChannelHeaderViewModifier(
        options: ChannelHeaderViewModifierOptions
    ) -> some ChatChannelHeaderViewModifier {
        ListingChannelHeaderModifier(channel: options.channel)
    }
}

// MARK: - Listing-aware channel header

private struct ListingChannelHeaderModifier: ChatChannelHeaderViewModifier {
    var channel: ChatChannel

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(channel.name ?? channel.cid.id)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        if let price = channel.extraData["listing_price"]?.numberValue {
                            Text("$\(Int(price))")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        startCall(audioOnly: true)
                    } label: {
                        Image(systemName: "phone.fill")
                            .foregroundStyle(Color.ooAccent)
                    }
                    .accessibilityLabel("Audio call")

                    Button {
                        startCall(audioOnly: false)
                    } label: {
                        Image(systemName: "video.fill")
                            .foregroundStyle(Color.ooAccent)
                    }
                    .accessibilityLabel("Video call")

                    if let peerId = otherMemberId {
                        Menu {
                            Button(role: .destructive) {
                                ChatService.shared.muteUser(peerId)
                            } label: { Label("Mute", systemImage: "speaker.slash.fill") }

                            Button(role: .destructive) {
                                ChatService.shared.blockUser(peerId)
                            } label: { Label("Block & report", systemImage: "flag.fill") }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
    }

    private var otherMemberId: String? {
        guard let currentId = ChatService.shared.currentUserId else { return nil }
        return channel.lastActiveMembers.first(where: { $0.id != currentId })?.id
    }

    private func startCall(audioOnly: Bool) {
        guard let peerId = otherMemberId else { return }
        let name = channel.lastActiveMembers.first(where: { $0.id == peerId })?.name ?? peerId
        NotificationCenter.default.post(
            name: AppEvents.startCall,
            object: StartCallRequest(
                calleeId: peerId,
                calleeName: name,
                audioOnly: audioOnly,
                listingTitle: channel.name
            )
        )
    }
}
