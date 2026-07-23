//
//  IMessageChatService.swift
//  SwiftUIFor27
//
//  Created by Amos Gyamfi on 22.7.2026.
//
//  Owns the Stream Chat client for the iMessage clone. This app also uses
//  StreamVideoSwiftUI (see IMessageCallService.swift), so Chat SDK
//  construction is isolated in this file — never import both Stream SDKs
//  in the same file (User/Token/ViewFactory names collide).
//
//  Backend: Stream app "StreamChatCoreAIModels" (app_id 1660832). The API
//  key is public; the token is a CLI-minted user JWT (`getstream token amos`),
//  so no API secret ever ships in the app.
//

#if os(iOS)
import StreamChat
import StreamChatSwiftUI
import UIKit

@MainActor
final class IMessageChatService {
    static let shared = IMessageChatService()

    /// The signed-in demo user. Also used to filter the channel list query.
    static let currentUserId = "amos"

    private(set) var chatClient: ChatClient?
    private(set) var streamChat: StreamChat?

    private init() {}

    private enum Credentials {
        static let apiKey = "4dz7gst7phy5"
        static let userId = IMessageChatService.currentUserId
        static let userName = "Amos Gyamfi"
        static let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE3ODQ3MDg3OTksInVzZXJfaWQiOiJhbW9zIn0.oHLkGt_ogk4xtBZM7CNNX5RE1Du5RCRd6e4WLzutH2E"
    }

    func setUpIfNeeded() {
        guard streamChat == nil else { return }

        var config = ChatClientConfig(apiKey: .init(Credentials.apiKey))
        config.isLocalStorageEnabled = true
        let client = ChatClient(config: config)
        chatClient = client

        // iMessage look: blue outgoing bubbles, blue accents everywhere.
        var colors = Appearance.ColorPalette()
        colors.accentPrimary = .systemBlue
        colors.navigationBarTintColor = .systemBlue
        colors.chatBackgroundOutgoing = .systemBlue
        var appearance = Appearance()
        appearance.colorPalette = colors

        streamChat = StreamChat(chatClient: client, appearance: appearance)

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
                print("iMessage clone: Stream Chat connect failed: \(error)")
            }
        }
    }
}
#endif
