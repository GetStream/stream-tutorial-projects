import SwiftUI
import StreamChat
import StreamChatSwiftUI

struct CustomChannelView: View {
    
    @State var channelInfoShown = false
    @State var messageDisplayInfo: MessageDisplayInfo?
    @StateObject var viewModel: ChatChannelViewModel
    
    @State private var isVideoCalling = false
    
    init() {
        _viewModel = StateObject(wrappedValue: ChatChannelViewModel(
            channelController: InjectedValues[\.chatClient].channelController(
                for: try! ChannelId(cid: "messaging:5A9427AD-E")
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
                        onMessageAppear: viewModel.handleMessageAppear(index:),
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
                .overlay(
                    viewModel.reactionsShown ?
                    ReactionsOverlayView(
                        factory: DefaultViewFactory.shared,
                        channel: channel,
                        currentSnapshot: viewModel.currentSnapshot!,
                        messageDisplayInfo: messageDisplayInfo!,
                        onBackgroundTap: {
                            viewModel.reactionsShown = false
                            messageDisplayInfo = nil
                        }, onActionExecuted: { actionInfo in
                            viewModel.messageActionExecuted(actionInfo)
                            messageDisplayInfo = nil
                        }
                    )
                    .transition(.identity)
                    .edgesIgnoringSafeArea(.all)
                    : nil
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button{
                            isVideoCalling.toggle()
                        } label: {
                            Image(systemName: "video.fill")
                        }
                        .fullScreenCover(isPresented: $isVideoCalling, content: CallContainerSetup.init)
                    }
                    
                    
                    DefaultChatChannelHeader(
                        channel: channel,
                        headerImage: InjectedValues[\.utils].channelHeaderLoader.image(for: channel),
                        isActive: $channelInfoShown
                    )
                }
            }
        }
    }
}
