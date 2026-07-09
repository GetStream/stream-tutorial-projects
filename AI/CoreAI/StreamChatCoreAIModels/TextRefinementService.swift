// TextRefinementService.swift
// AI text actions for the message composer — refine, summarize, fix grammar,
// and change style — powered by a FoundationModels LanguageModelSession.
//
// The session's model comes from AIModelPreferences.textModel:
//   * Apple Intelligence — SystemLanguageModel.default (on-device).
//   * Core AI zoo bundle — CoreAILanguageModel(resourcesAt:) behind the same
//     LanguageModelSession API (identical streaming code path).

import CoreAILanguageModels
import Foundation
import FoundationModels
import Observation

enum ComposerTextAction: String, CaseIterable, Identifiable, Sendable {
    case refine
    case summarize
    case fixGrammar
    case styleProfessional
    case styleFriendly
    case styleConcise
    case stylePoetic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .refine: "Refine"
        case .summarize: "Summarize"
        case .fixGrammar: "Grammar"
        case .styleProfessional: "Professional"
        case .styleFriendly: "Friendly"
        case .styleConcise: "Concise"
        case .stylePoetic: "Poetic"
        }
    }

    var symbolName: String {
        switch self {
        case .refine: "wand.and.stars"
        case .summarize: "text.line.first.and.arrowtriangle.forward"
        case .fixGrammar: "textformat.abc.dottedunderline"
        case .styleProfessional: "briefcase"
        case .styleFriendly: "face.smiling"
        case .styleConcise: "arrow.down.right.and.arrow.up.left"
        case .stylePoetic: "sparkles"
        }
    }

    var isStyle: Bool {
        switch self {
        case .styleProfessional, .styleFriendly, .styleConcise, .stylePoetic: true
        default: false
        }
    }

    static var styles: [ComposerTextAction] {
        allCases.filter(\.isStyle)
    }

    var instruction: String {
        switch self {
        case .refine:
            "Rewrite the message to be clearer and better phrased while keeping its meaning, tone, and language."
        case .summarize:
            "Summarize the message into one or two short sentences that keep the key points."
        case .fixGrammar:
            "Fix all spelling, grammar, and punctuation mistakes. Change nothing else."
        case .styleProfessional:
            "Rewrite the message in a polished, professional tone suitable for a workplace chat."
        case .styleFriendly:
            "Rewrite the message in a warm, casual, friendly tone."
        case .styleConcise:
            "Rewrite the message to be as short and direct as possible without losing meaning."
        case .stylePoetic:
            "Rewrite the message with a playful, lightly poetic flair. Keep it short."
        }
    }
}

@MainActor
@Observable
final class TextRefinementService {
    enum Phase: Equatable {
        case idle
        case loading(String)
        case generating(ComposerTextAction)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    /// The draft as it was before the last AI action, for undo.
    private(set) var undoText: String?

    var isBusy: Bool {
        switch phase {
        case .loading, .generating: true
        default: false
        }
    }

    var errorMessage: String? {
        if case .failed(let message) = phase { return message }
        return nil
    }

    /// Only one multi-GB zoo model stays in memory at a time.
    private var loadedZooModel: (id: String, model: CoreAILanguageModel)?

    private static let instructions = """
        You are a writing assistant inside a chat app. You receive a task and \
        a message draft. Reply with ONLY the rewritten message text - no \
        preamble, no quotes, no explanations.
        """

    /// Applies `action` to `text`, streaming the rewrite through `onUpdate`.
    func apply(
        _ action: ComposerTextAction,
        to text: String,
        using choice: ChatModelChoice,
        onUpdate: @escaping (String) -> Void
    ) async {
        let draft = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.isEmpty, !isBusy else { return }

        undoText = text
        do {
            let session = try await makeSession(for: choice)
            phase = .generating(action)

            let prompt = """
                Task: \(action.instruction)

                Message draft:
                \(draft)
                """
            let stream = session.streamResponse(
                to: prompt,
                options: GenerationOptions(maximumResponseTokens: 512)
            )
            var latest = draft
            for try await snapshot in stream {
                latest = Self.cleaned(snapshot.content)
                onUpdate(latest)
            }
            onUpdate(Self.cleaned(latest))
            phase = .idle
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func undo(onUpdate: (String) -> Void) {
        guard let original = undoText else { return }
        onUpdate(original)
        undoText = nil
    }

    func dismissError() {
        if case .failed = phase { phase = .idle }
    }

    // MARK: - Session plumbing

    private func makeSession(for choice: ChatModelChoice) async throws -> LanguageModelSession {
        phase = .loading(choice.displayName)
        switch choice {
        case .appleFoundationModel:
            switch SystemLanguageModel.default.availability {
            case .available:
                return LanguageModelSession(model: .default, instructions: Self.instructions)
            case .unavailable(let reason):
                throw NSError(
                    domain: "TextRefinement", code: 1,
                    userInfo: [NSLocalizedDescriptionKey:
                        "Apple's on-device model is unavailable (\(String(describing: reason))). "
                        + "Enable Apple Intelligence, or pick a Core AI model in settings."]
                )
            }

        case .zoo(let zoo):
            guard ZooModelCatalog.isInstalled(zoo) else {
                throw NSError(
                    domain: "TextRefinement", code: 2,
                    userInfo: [NSLocalizedDescriptionKey:
                        "\(zoo.displayName) is not downloaded yet. Fetch it from the model settings."]
                )
            }
            if let loaded = loadedZooModel, loaded.id == zoo.id {
                return LanguageModelSession(model: loaded.model, instructions: Self.instructions)
            }
            loadedZooModel = nil
            // Zoo pipelined bundles are decode-only S=1 graphs.
            if getenv("COREAI_CHUNK_THRESHOLD") == nil {
                setenv("COREAI_CHUNK_THRESHOLD", "1", 1)
            }
            let model = try await CoreAILanguageModel(resourcesAt: ZooModelCatalog.bundleURL(for: zoo))
            loadedZooModel = (zoo.id, model)
            return LanguageModelSession(model: model, instructions: Self.instructions)
        }
    }

    /// Strips wrapping quotes/whitespace some models add despite instructions.
    private static func cleaned(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for quote in ["\"", "\u{201C}", "\u{201D}"] where
            result.hasPrefix(quote) && result.hasSuffix(quote) && result.count > 2 {
            result = String(result.dropFirst().dropLast())
        }
        return result
    }
}
