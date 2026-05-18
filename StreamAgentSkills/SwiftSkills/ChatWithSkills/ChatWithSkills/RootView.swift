//
//  RootView.swift
//  ChatWithSkills
//
//  Gates the app on Stream Chat login state. Shows the login picker
//  while no user is connected, then switches to the channel list once
//  `connectUser` succeeds.
//

import SwiftUI
import StreamChat
import StreamChatSwiftUI

struct RootView: View {
    @Injected(\.chatClient) private var chatClient
    @State private var isConnected = false

    var body: some View {
        Group {
            if isConnected {
                ChannelListScreen(onLogout: handleLogout)
            } else {
                LoginView(onConnected: {
                    isConnected = true
                })
            }
        }
        .onAppear {
            isConnected = chatClient.currentUserId != nil
        }
    }

    private func handleLogout() {
        chatClient.logout {
            DispatchQueue.main.async {
                isConnected = false
            }
        }
    }
}

#Preview {
    RootView()
}
