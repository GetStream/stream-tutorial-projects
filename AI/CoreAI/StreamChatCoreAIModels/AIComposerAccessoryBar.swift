#if os(iOS)
// AIComposerAccessoryBar.swift
// The AI strip that sits directly above the Stream message composer:
//
//   [mic] | Refine · Summarize · Grammar · Style ▾ | [undo]
//
//   * Mic — voice input with the selected ASR engine (SpeechAnalyzer
//     streams live; Whisper/Wav2Vec record then transcribe).
//   * Refine / Summarize / Grammar / Style — rewrite the draft with the
//     selected Foundation Models / Core AI text model, streaming in place.
//
// Photo Q&A needs no button here: attach a photo with the composer's
// standard media picker, type a question, and send — MiniCPM-V streams its
// answer into the chat (see MiniCPMChatResponder).
//
// The bar shares the `MessageComposerViewModel` with the SDK composer, so
// every action reads and writes the real draft text.

import StreamChat
import StreamChatSwiftUI
import SwiftUI

struct AIComposerAccessoryBar: View {
    @ObservedObject var composerViewModel: MessageComposerViewModel

    @State private var preferences = AIModelPreferences.shared
    @State private var voiceInput = VoiceInputController()
    @State private var refinement = TextRefinementService()
    @State private var visionResponder = MiniCPMChatResponder.shared

    private var draftIsEmpty: Bool {
        composerViewModel.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 4) {
            statusLine
            GlassEffectContainer(spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            actionChip(.refine)
                            actionChip(.summarize)
                            actionChip(.fixGrammar)
                            styleMenu
                        }
                    }

                    HStack(spacing: 12) {
                        micButton
                        if refinement.undoText != nil {
                            undoButton
                        }
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(.bar)
    }

    // MARK: - Status / errors

    @ViewBuilder
    private var statusLine: some View {
        if case .generating(let action) = refinement.phase {
            statusText("\(action.title) with \(preferences.textModel.displayName)…", spinning: true)
        } else if case .loading(let name) = refinement.phase {
            statusText("Loading \(name)…", spinning: true)
        } else if voiceInput.phase == .transcribing {
            statusText("Transcribing with \(preferences.speechModel.displayName)…", spinning: true)
        } else if voiceInput.phase == .recording {
            statusText("Recording — tap the mic to finish", spinning: false)
        } else if visionResponder.phase == .loading {
            statusText("Loading \(preferences.visionModel.displayName)…", spinning: true)
        } else if visionResponder.phase == .reading {
            statusText("\(preferences.visionModel.displayName) is looking at the photo…", spinning: true)
        } else if visionResponder.phase == .answering {
            statusText("\(preferences.visionModel.displayName) is answering…", spinning: true)
        } else if let error = refinement.errorMessage ?? voiceInput.errorMessage ?? visionResponder.errorMessage {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(error)
                    .lineLimit(2)
                Spacer()
                Button("Dismiss") {
                    refinement.dismissError()
                    voiceInput.dismissError()
                    visionResponder.dismissError()
                }
                .font(.caption.weight(.semibold))
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.top, 6)
        }
    }

    private func statusText(_ text: String, spinning: Bool) -> some View {
        HStack(spacing: 6) {
            if spinning {
                ProgressView().controlSize(.mini)
            }
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    // MARK: - Voice input

    private var micButton: some View {
        Button {
            refinement.dismissError()
            voiceInput.toggle(
                model: preferences.speechModel,
                currentText: composerViewModel.text
            ) { updated in
                composerViewModel.text = updated
            }
        } label: {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 28))
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.variableColor.iterative, isActive: voiceInput.isActive)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .foregroundStyle(voiceInput.isActive ? Color.red : Color.accentColor)
        .disabled(voiceInput.phase == .transcribing)
        .accessibilityLabel(
            voiceInput.isActive
                ? "Stop voice input"
                : "Dictate with \(preferences.speechModel.displayName)"
        )
    }

    // MARK: - Text actions

    private func actionChip(_ action: ComposerTextAction) -> some View {
        Button {
            run(action)
        } label: {
            Label(action.title, systemImage: action.symbolName)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .disabled(draftIsEmpty || refinement.isBusy)
        .opacity(draftIsEmpty || refinement.isBusy ? 0.45 : 1)
    }

    private var styleMenu: some View {
        Menu {
            ForEach(ComposerTextAction.styles) { style in
                Button {
                    run(style)
                } label: {
                    Label(style.title, systemImage: style.symbolName)
                }
            }
        } label: {
            Label("Style", systemImage: "paintbrush")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .glassEffect(.regular.interactive(), in: .capsule)
        .disabled(draftIsEmpty || refinement.isBusy)
        .opacity(draftIsEmpty || refinement.isBusy ? 0.45 : 1)
    }

    private var undoButton: some View {
        Button {
            refinement.undo { composerViewModel.text = $0 }
        } label: {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Undo AI rewrite")
    }

    private func run(_ action: ComposerTextAction) {
        voiceInput.dismissError()
        Task {
            await refinement.apply(
                action,
                to: composerViewModel.text,
                using: preferences.textModel
            ) { updated in
                composerViewModel.text = updated
            }
        }
    }
}
#endif
