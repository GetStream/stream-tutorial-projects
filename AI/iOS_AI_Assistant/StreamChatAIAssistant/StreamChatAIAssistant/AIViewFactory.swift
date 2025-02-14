//
//  AIViewFactory.swift
//  StreamChatAIAssistant
//
//  Created by Martin Mitrevski on 25.11.24.
//

import SwiftUI
import StreamChat
import StreamChatAI
import StreamChatSwiftUI

class AIViewFactory: ViewFactory {
    
    @Injected(\.chatClient) var chatClient: ChatClient
    
    let typingIndicatorHandler: TypingIndicatorHandler
    
    init(typingIndicatorHandler: TypingIndicatorHandler) {
        self.typingIndicatorHandler = typingIndicatorHandler
    }

    func makeMessageListContainerModifier() -> some ViewModifier {
        CustomMessageListContainerModifier(typingIndicatorHandler: typingIndicatorHandler)
    }
    
    func makeEmptyMessagesView(
        for channel: ChatChannel,
        colors: ColorPalette
    ) -> some View {
        AIAgentOverlayView(typingIndicatorHandler: typingIndicatorHandler)
    }
    
    @ViewBuilder
    func makeCustomAttachmentViewType(
        for message: ChatMessage,
        isFirst: Bool,
        availableWidth: CGFloat,
        scrolledId: Binding<String?>
    ) -> some View {
        StreamingAIView(
            typingIndicatorHandler: typingIndicatorHandler,
            message: message,
            isFirst: isFirst
        )
    }
    
    func makeTrailingComposerView(
        enabled: Bool,
        cooldownDuration: Int,
        onTap: @escaping () -> Void
    ) -> some View {
        CustomTrailingComposerView(
            typingIndicatorHandler: typingIndicatorHandler,
            onTap: onTap
        )
    }
}

struct StreamingAIView: View {
    
    @ObservedObject var typingIndicatorHandler: TypingIndicatorHandler

    var message: ChatMessage
    var isFirst: Bool
        
    var body: some View {
        StreamingMessageView(
            content: message.text,
            isGenerating: typingIndicatorHandler.generatingMessageId == message.id
        )
        .padding()
        .messageBubble(for: message, isFirst: isFirst)
    }
    
}

struct CustomMessageListContainerModifier: ViewModifier {
    
    @ObservedObject var typingIndicatorHandler: TypingIndicatorHandler
    
    func body(content: Content) -> some View {
        content.overlay {
            AIAgentOverlayView(typingIndicatorHandler: typingIndicatorHandler)
        }
    }
}

struct AIAgentOverlayView: View {
    
    @ObservedObject var typingIndicatorHandler: TypingIndicatorHandler
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                if !typingIndicatorHandler.aiBotPresent {
                    Button {
                        Task {
                            if let channelId = typingIndicatorHandler.channelId {
                                try await StreamAIChatService.shared.setupAgent(channelId: channelId.id)
                            }
                        }
                    } label: {
                        AIIndicatorButton(title: "Start AI")
                    }
                } else {
                    Button {
                        Task {
                            if let channelId = typingIndicatorHandler.channelId {
                                try await StreamAIChatService.shared.stopAgent(channelId: channelId.id)
                            }
                        }
                    } label: {
                        AIIndicatorButton(title: "Stop AI")
                    }
                    
                }
            }
            Spacer()
            if typingIndicatorHandler.typingIndicatorShown {
                HStack {
                    AITypingIndicatorView(text: typingIndicatorHandler.state)
                    Spacer()
                }
                .padding()
                .frame(height: 80)
                .background(Color(UIColor.secondarySystemBackground))
            }
        }
    }
}

struct AIIndicatorButton: View {
    
    let title: String
        
    var body: some View {
        HStack {
            Text(title)
                .bold()
            Image(systemName: "wand.and.stars.inverse")
        }
        .padding(.all, 8)
        .padding(.horizontal, 4)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 12)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        .padding()
    }
}

struct CustomTrailingComposerView: View {
    
    @Injected(\.utils) private var utils
        
    @EnvironmentObject var viewModel: MessageComposerViewModel
    
    var onTap: () -> Void
    
    @ObservedObject var typingIndicatorHandler: TypingIndicatorHandler
        
    init(
        typingIndicatorHandler: TypingIndicatorHandler,
        onTap: @escaping () -> Void
    ) {
        self.typingIndicatorHandler = typingIndicatorHandler
        self.onTap = onTap
    }
    
    public var body: some View {
        Group {
            if typingIndicatorHandler.generatingMessageId != nil {
                Button {
                    Task {
                        viewModel.channelController
                            .eventsController()
                            .sendEvent(
                                AIIndicatorStopEvent(cid: viewModel.channelController.channel?.cid)
                            )
                    }
                } label: {
                    Image(systemName: "stop.circle.fill")
                }
            } else {
                SendMessageButton(
                    enabled: viewModel.sendButtonEnabled,
                    onTap: onTap
                )
            }
        }
        .padding(.bottom, 8)
    }
}
