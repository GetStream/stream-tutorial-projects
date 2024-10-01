import StreamChat
import StreamChatSwiftUI
import SwiftUI

struct CustomChannelView: View {

    @State var channelInfoShown = false
    @State var messageDisplayInfo: MessageDisplayInfo?
    @StateObject var viewModel: ChatChannelViewModel

    init(channelId: ChannelId) {
        _viewModel = StateObject(
            wrappedValue: ChatChannelViewModel(
                channelController: InjectedValues[\.chatClient].channelController(
                    for: channelId
                ))
        )
    }

    var body: some View {
        NavigationView {
            if let channel = viewModel.channel {
                VStack(spacing: 0) {
                    MessageListView(
                        factory: DefaultViewFactory.shared,
                        channel: channel,
                        messages: viewModel.messages,
                        messagesGroupingInfo: viewModel.messagesGroupingInfo,
                        scrolledId: $viewModel.scrolledId,
                        showScrollToLatestButton: $viewModel.showScrollToLatestButton,
                        quotedMessage: $viewModel.quotedMessage,
                        currentDateString: viewModel.currentDateString,
                        listId: viewModel.listId,
                        onMessageAppear: viewModel.handleMessageAppear(index:scrollDirection:),
                        onScrollToBottom: viewModel.scrollToLastMessage,
                        onLongPress: { displayInfo in
                            messageDisplayInfo = displayInfo
                            withAnimation {
                                viewModel.showReactionOverlay(for: AnyView(self))
                            }
                        }
                    )

                    MessageComposerView(
                        viewFactory: DefaultViewFactory.shared,
                        channelController: viewModel.channelController,
                        quotedMessage: $viewModel.quotedMessage,
                        editedMessage: $viewModel.editedMessage,
                        onMessageSent: viewModel.scrollToLastMessage
                    )
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    DefaultChatChannelHeader(
                        channel: channel,
                        headerImage: InjectedValues[\.utils].channelHeaderLoader.image(
                            for: channel),
                        isActive: $channelInfoShown
                    )
                }
            }
        }
    }
}
