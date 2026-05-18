//
//  ChatWithSkillsApp.swift
//  ChatWithSkills
//
//  Created by Amos Gyamfi on 13.5.2026.
//

import SwiftUI
import StreamChat
import StreamChatSwiftUI

@main
struct ChatWithSkillsApp: App {
    @State private var streamChat: StreamChat

    init() {
        var config = ChatClientConfig(apiKey: .init(StreamConfig.apiKey))
        config.isLocalStorageEnabled = true
        config.isAutomaticSyncOnReconnectEnabled = true
        config.staysConnectedInBackground = true

        let chatClient = ChatClient(config: config)
        _streamChat = State(wrappedValue: StreamChat(chatClient: chatClient))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
