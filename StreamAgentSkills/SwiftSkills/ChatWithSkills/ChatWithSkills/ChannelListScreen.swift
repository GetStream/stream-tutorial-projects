//
//  ChannelListScreen.swift
//  ChatWithSkills
//
//  Hosts the Stream Chat channel list filtered to the signed-in user's
//  channels. `ChatChannelListView` ships its own navigation container,
//  message list, composer, threads, reactions, and attachments — no
//  extra wiring required.
//

import SwiftUI
import StreamChat
import StreamChatSwiftUI

struct ChannelListScreen: View {
    @Injected(\.chatClient) private var chatClient
    @State private var channelListController: ChatChannelListController?
    let onLogout: () -> Void

    var body: some View {
        ZStack {
            if let channelListController {
                ChatChannelListView(
                    channelListController: channelListController,
                    title: "Messages"
                )
            } else {
                ProgressView("Loading conversations…")
            }
        }
        .task {
            guard channelListController == nil,
                  let userId = chatClient.currentUserId else { return }
            channelListController = chatClient.channelListController(
                query: .init(
                    filter: .containMembers(userIds: [userId]),
                    sort: [.init(key: .lastMessageAt, isAscending: false)],
                    pageSize: 20
                )
            )
        }
        .overlay(alignment: .topTrailing) {
            Button {
                onLogout()
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.body.weight(.semibold))
                    .padding(10)
                    .background(.thinMaterial, in: Circle())
            }
            .padding(.trailing, 16)
            .padding(.top, 8)
            .accessibilityLabel("Sign out")
        }
    }
}
