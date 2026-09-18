import StreamChatAI
import SwiftUI

/// Live captions on top of the camera: the session state (via
/// `AITypingIndicatorView`), what the user just said, and the model's reply
/// streamed through `StreamingMessageView` (markdown, code, tables).
struct LiveCaptionStrip: View {
    @ObservedObject var model: LiveSessionViewModel

    private var latestModel: TranscriptEntry? { model.transcript.last(where: { $0.role == .model }) }
    private var latestUser: TranscriptEntry? { model.transcript.last(where: { $0.role == .user }) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if model.mode == .transcribe {
                transcribeCaption
            } else {
                if let user = latestUser, !user.text.isEmpty {
                    Text(user.text)
                        .font(.footnote)
                        .foregroundStyle(Aurora.textSecondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                }

                if let reply = latestModel, !reply.text.isEmpty {
                    ScrollView {
                        StreamingMessageView(content: reply.text, isGenerating: !reply.isFinal, letterInterval: 0.004)
                            .font(.body)
                            .foregroundStyle(Aurora.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollIndicators(.hidden)
                    .defaultScrollAnchor(.bottom)
                    .frame(maxHeight: 132)
                    .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .auroraGlass(cornerRadius: 24, tint: Aurora.indigo900.opacity(0.18))
        .animation(.easeInOut(duration: 0.2), value: model.transcript.count)
        .animation(.easeInOut(duration: 0.2), value: model.phase)
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 10) {
            switch model.phase {
            case .speaking:
                Image(systemName: "waveform")
                    .symbolEffect(.variableColor.iterative, isActive: true)
                    .foregroundStyle(Aurora.haloSky)
                Text("Speaking")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Aurora.textPrimary)
            case let .failed(message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Aurora.haloPeach)
                Text(message)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Aurora.textPrimary)
                    .lineLimit(2)
            default:
                AITypingIndicatorView(text: model.isMicMuted && model.phase == .listening ? "Muted" : model.phase.label)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Aurora.textPrimary)
            }

            Spacer(minLength: 0)

            Label(model.mode.shortTitle, systemImage: model.mode.symbol)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Aurora.textSecondary)
                .labelStyle(.titleAndIcon)
        }
    }

    private var transcribeCaption: some View {
        Group {
            if let user = latestUser, !user.text.isEmpty {
                Text(user.text)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Aurora.textPrimary)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.interpolate)
            } else {
                Text("Start talking - Gemini 3.5 Transcribe captions your English speech live.")
                    .font(.footnote)
                    .foregroundStyle(Aurora.textSecondary)
            }
        }
    }
}
