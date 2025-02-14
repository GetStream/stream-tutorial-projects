import SwiftUI
import StreamChat
import StreamChatSwiftUI

@main
struct StreamChatAIAssistantApp: App {

    @State var streamChat: StreamChat
    @State var typingIndicatorHandler: TypingIndicatorHandler
    @StateObject var channelListViewModel: ChatChannelListViewModel

    var chatClient: ChatClient = {
        var config = ChatClientConfig(apiKey: .init("zcgvnykxsfm8"))
        config.isLocalStorageEnabled = true
        config.applicationGroupIdentifier = "group.amosgyamfi.StreamChatAIAssistant"

        let client = ChatClient(config: config)
        return client
    }()

    init() {
        let utils = Utils(
            messageTypeResolver: CustomMessageResolver(),
            messageListConfig: .init(
                messageDisplayOptions: .init(spacerWidth: { _ in return 60 }),
                skipEditedMessageLabel: { message in
                    message.extraData["ai_generated"]?.boolValue == true
                }
            )
        )
        _streamChat = State(initialValue: StreamChat(chatClient: chatClient, utils: utils))
        typingIndicatorHandler = TypingIndicatorHandler()
        _channelListViewModel = StateObject(wrappedValue: ViewModelsFactory.makeChannelListViewModel())

        chatClient.connectUser(
            userInfo: UserInfo(
               id: "anakin_skywalker",
               imageURL: URL(string: "https://vignette.wikia.nocookie.net/starwars/images/6/6f/Anakin_Skywalker_RotS.png")
            ),
            token: try! Token(rawValue: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiYW5ha2luX3NreXdhbGtlciJ9.ZwCV1qPrSAsie7-0n61JQrSEDbp6fcMgVh4V2CB0kM8")
        )
    }

    var body: some Scene {
        WindowGroup {
            ChatChannelListView(
                viewFactory: AIViewFactory(typingIndicatorHandler: typingIndicatorHandler),
                viewModel: channelListViewModel
            )
            .onChange(of: channelListViewModel.selectedChannel) { oldValue, newValue in
                typingIndicatorHandler.channelId = newValue?.channel.cid
                if newValue == nil, let channelId = oldValue?.channel.cid.id {
                    Task {
                        try await StreamAIChatService.shared.stopAgent(channelId: channelId)
                    }
                }
            }
        }
    }
}

class CustomMessageResolver: MessageTypeResolving {

    func hasCustomAttachment(message: ChatMessage) -> Bool {
        message.extraData["ai_generated"] == true
    }
}
