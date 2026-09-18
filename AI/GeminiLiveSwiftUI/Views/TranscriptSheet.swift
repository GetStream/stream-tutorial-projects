import StreamChatAI
import SwiftUI

/// Full conversation transcript rendered with the Stream AI components:
/// model turns stream through `StreamingMessageView`, starter prompts come
/// from `SuggestionsView`, and `ComposerView` lets you type into the live
/// session (with speech-to-text from the SDK's mic button).
struct TranscriptSheet: View {
    @ObservedObject var model: LiveSessionViewModel
    @StateObject private var composer = ComposerViewModel()
    @State private var composerGeneration = 0

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if model.transcript.isEmpty {
                            emptyState
                        }
                        ForEach(model.transcript) { entry in
                            row(for: entry).id(entry.id)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: model.transcript.last?.text) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }

            if model.mode.speaks {
                composerBar
            } else {
                Text("Transcribe mode captions your speech only. Switch to Gemini Live to chat.")
                    .font(.footnote)
                    .foregroundStyle(Aurora.textSecondary)
                    .padding(.vertical, 14)
            }
        }
        .background(AuroraBackground().ignoresSafeArea())
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            AuroraOrb(size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("Transcript")
                    .font(.headline)
                    .foregroundStyle(Aurora.textPrimary)
                Text(model.mode.title)
                    .font(.caption)
                    .foregroundStyle(Aurora.textSecondary)
            }
            Spacer()
            if !model.transcript.isEmpty {
                Button {
                    withAnimation { model.clearTranscript() }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Aurora.textPrimary)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .auroraGlassCircle(interactive: true)
                .accessibilityLabel("Clear transcript")
            }
        }
    }

    // MARK: Rows

    @ViewBuilder
    private func row(for entry: TranscriptEntry) -> some View {
        switch entry.role {
        case .user:
            HStack {
                Spacer(minLength: 48)
                Text(entry.text)
                    .font(.body)
                    .foregroundStyle(Aurora.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .auroraGlass(cornerRadius: 20, tint: Aurora.periwinkle600.opacity(0.35))
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))

        case .model:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    AuroraOrb(size: 16)
                    Text("Gemini")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Aurora.textSecondary)
                    if !entry.isFinal {
                        AITypingIndicatorView(text: "")
                            .font(.caption)
                    }
                }
                StreamingMessageView(content: entry.text, isGenerating: !entry.isFinal)
                    .foregroundStyle(Aurora.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 4)
            .transition(.opacity)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text(model.mode.speaks
                 ? "Nothing yet. Say something, or start with one of these:"
                 : "Nothing yet. Start talking and your words appear here.")
                .font(.subheadline)
                .foregroundStyle(Aurora.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if model.mode.speaks {
                SuggestionsView(
                    suggestions: StreamLiveConfig.starterPrompts,
                    height: 96,
                    itemMaxWidth: 190,
                    colors: Self.colors,
                    onMessageSend: { send($0) }
                )
                .padding(.horizontal, -16)
            }
        }
        .padding(.top, 12)
    }

    // MARK: Composer

    private var composerBar: some View {
        StreamChatAI.ComposerView(
            viewFactory: LiveComposerFactory(generation: composerGeneration, onSend: { send($0) }, onStop: { model.interrupt() }),
            viewModel: composer,
            colors: Self.colors,
            isGenerating: model.isModelSpeaking,
            onMessageSend: { send($0) },
            onStopGenerating: { model.interrupt() }
        )
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .auroraGlass(cornerRadius: 30, interactive: true)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func send(_ data: MessageData) {
        model.sendText(data.text)
        composer.cleanUpData()
        composerGeneration += 1
    }

    /// Aurora palette mapped onto the AI components' color model.
    static let colors: StreamChatAI.Colors = {
        let p = Aurora.aiComponentColors
        return StreamChatAI.Colors(
            composer: .init(
                attachmentButtonBackground: p.attachmentButtonBackground,
                attachmentButtonIcon: p.attachmentButtonIcon,
                containerBackground: p.containerBackground,
                containerForeground: p.containerForeground,
                selectedOptionBackground: p.selectedOptionBackground,
                selectedOptionForeground: p.selectedOptionForeground
            ),
            suggestions: .init(text: p.suggestionText, background: p.suggestionBackground),
            transcription: .init(icon: p.transcriptionIcon)
        )
    }()
}

/// Composer without the attachment slot (frames already stream from the
/// camera) and with a fresh input identity after each send so the field clears.
final class LiveComposerFactory: ComposerViewFactory {
    private let generation: Int
    private let onSend: (MessageData) -> Void
    private let onStop: () -> Void

    init(generation: Int, onSend: @escaping (MessageData) -> Void, onStop: @escaping () -> Void) {
        self.generation = generation
        self.onSend = onSend
        self.onStop = onStop
    }

    func makeLeadingComposerView(options: StreamChatAI.LeadingComposerViewOptions) -> some View {
        EmptyView()
    }

    func makeComposerInputView(options: StreamChatAI.ComposerInputViewOptions) -> some View {
        let onSend = onSend
        let onStop = onStop
        return ComposerInputView(
            viewModel: options.viewModel,
            speechHandler: options.speechHandler,
            colors: options.colors,
            isGenerating: options.isGenerating,
            onMessageSend: { onSend($0) },
            onStopGenerating: { onStop() }
        )
        .id(generation)
    }

    func makeTrailingComposerView(options: StreamChatAI.TrailingComposerViewOptions) -> some View {
        EmptyView()
    }
}
