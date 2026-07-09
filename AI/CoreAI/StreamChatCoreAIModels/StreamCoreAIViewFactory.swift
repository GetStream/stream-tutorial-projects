#if os(iOS)
// StreamCoreAIViewFactory.swift
// Stream Chat SwiftUI ViewFactory customizations for the Core AI chat app:
//
//   * Channel header — adds a trailing "model settings" toolbar button that
//     opens the AI model picker (speech-to-text, text refinement, image gen).
//   * Message composer — wraps the SDK composer with the AI accessory bar
//     (voice input, refine/summarize/grammar/style, image generation). The
//     composer view model is created here and shared with the bar so AI
//     actions can read and rewrite the draft text directly.

import StreamChat
import StreamChatSwiftUI
import SwiftUI

final class StreamCoreAIViewFactory: ViewFactory {
    @Injected(\.chatClient) var chatClient

    static let shared = StreamCoreAIViewFactory()
    private init() {}

    var styles = RegularStyles()

    /// One composer view model per channel, shared between the SDK composer
    /// and the AI accessory bar. Keyed by channel id.
    private var composerViewModels: [String: MessageComposerViewModel] = [:]

    private func composerViewModel(
        for options: MessageComposerViewTypeOptions
    ) -> MessageComposerViewModel {
        let key = options.channelController.cid?.rawValue ?? "unknown-channel"
        if let existing = composerViewModels[key] { return existing }
        let viewModel = ViewModelsFactory.makeMessageComposerViewModel(
            with: options.channelController,
            messageController: options.messageController,
            quotedMessage: options.quotedMessage,
            editedMessage: options.editedMessage,
            willSendMessage: options.willSendMessage
        )
        composerViewModels[key] = viewModel
        return viewModel
    }

    // MARK: - Channel header (trailing model-settings button)

    func makeChannelHeaderViewModifier(
        options: ChannelHeaderViewModifierOptions
    ) -> some ChatChannelHeaderViewModifier {
        CoreAIChannelHeaderModifier(channel: options.channel)
    }

    // MARK: - Composer with the AI accessory bar

    func makeMessageComposerViewType(
        options: MessageComposerViewTypeOptions
    ) -> some View {
        let viewModel = composerViewModel(for: options)
        // Chain the SDK's send callback with the MiniCPM photo-Q&A hook.
        // `willSendMessage` fires while the draft text and attachments are
        // still in the composer, which is exactly what the responder needs.
        let sdkWillSendMessage = options.willSendMessage
        viewModel.willSendMessage = { [weak viewModel] in
            sdkWillSendMessage()
            guard let viewModel else { return }
            MiniCPMChatResponder.shared.handleSentMessage(from: viewModel)
        }
        return VStack(spacing: 0) {
            AIComposerAccessoryBar(composerViewModel: viewModel)
            MessageComposerView(
                viewFactory: self,
                viewModel: viewModel,
                channelController: options.channelController,
                messageController: options.messageController,
                quotedMessage: options.quotedMessage,
                editedMessage: options.editedMessage,
                willSendMessage: options.willSendMessage
            )
        }
    }

}

/// Channel header: channel name in the middle, AI model settings on the right.
struct CoreAIChannelHeaderModifier: ChatChannelHeaderViewModifier {
    var channel: ChatChannel
    @State private var showModelSettings = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(channel.name ?? channel.cid.id)
                            .font(.headline)
                        Text("On-device AI chat")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showModelSettings = true
                    } label: {
                        Image(systemName: "brain.head.profile")
                    }
                    .accessibilityLabel("AI model settings")
                }
            }
            .sheet(isPresented: $showModelSettings) {
                AIModelSettingsView()
            }
    }
}
#endif
