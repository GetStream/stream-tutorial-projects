#if os(iOS)
// StreamBotRun.swift
// A unit of handed-off work, and how it rides inside a Stream message.
//
// A run is the thing that makes a bot feel like a teammate rather than a chat
// completion: it has a plan the user can watch tick over, it stops at an
// approval gate when the bot's policy says it must, and it survives the app
// being killed because its state lives on the message itself.
//
// Transport: the whole run is JSON-encoded into the bot message's `extraData`
// under `grok_run`. Stream already syncs, persists and paginates messages, so
// putting the run there means "keeps going after you close your laptop" needs
// no separate store and no server — reopening the thread rehydrates every run
// exactly as it was, on any device signed into the same Stream user.

import Foundation
import StreamChat

// MARK: - Message kinds

/// Discriminator written into `extraData["grok_kind"]` so the view factory can
/// route a message to the right renderer without inspecting its text.
enum StreamBotMessageKind: String, Sendable {
    /// Carries a `StreamBotRun` and renders as the plan/approval card.
    case run
    /// A bot's prose answer. Rendered with a caret while it is still arriving.
    case reply
    /// One bot passing work to another inside a room.
    case handoff
    /// Confirmation that a routine was learned from the conversation.
    case routine

    static func of(_ message: StreamChatMessage) -> StreamBotMessageKind? {
        message.extraData["grok_kind"]?.stringValue
            .flatMap(StreamBotMessageKind.init(rawValue:))
    }
}

// `StreamChatMessage` rather than `ChatMessage` throughout: this target declares
// its own `ChatMessage` struct for the standalone Core AI chat demo, and a
// same-module type wins name resolution over one from an imported module. The
// alias (declared in RichTextFormat.swift) is the unambiguous Stream message.
extension StreamChatMessage {
    /// True while a bot is still writing this message. The runtime clears the
    /// flag on its last edit, so a message left mid-stream by a crash shows as
    /// interrupted rather than hanging forever.
    var streamBotIsStreaming: Bool {
        extraData["grok_streaming"]?.boolValue ?? false
    }

    /// The bot that authored this message, resolved against the roster.
    func streamBotBot(in roster: [String: StreamBotTeammate]) -> StreamBotTeammate? {
        roster[author.id]
    }

    var streamBotRun: StreamBotRun? {
        guard let json = extraData["grok_run"]?.stringValue else { return nil }
        return StreamBotRun(json: json)
    }
}

// MARK: - Step

struct StreamBotRunStep: Identifiable, Codable, Hashable, Sendable {
    enum Status: String, Codable, Sendable {
        case pending
        case active
        case done
        case blocked
        case skipped
    }

    var id: String
    var title: String
    /// Which declared surface this step happens in, when the planner named one.
    var workspace: StreamBotWorkspace?
    var status: Status
    /// What the bot found or produced, filled in as the step completes.
    var note: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        workspace: StreamBotWorkspace? = nil,
        status: Status = .pending,
        note: String? = nil
    ) {
        self.id = id
        self.title = title
        self.workspace = workspace
        self.status = status
        self.note = note
    }
}

// MARK: - Run

struct StreamBotRun: Identifiable, Codable, Hashable, Sendable {
    enum Status: String, Codable, Sendable {
        /// Model is turning the request into a plan.
        case planning
        /// Working through the steps.
        case working
        /// Finished the work; policy requires a tap before it counts as done.
        case awaitingApproval
        case approved
        case rejected
        /// Finished and reported, no approval needed.
        case done
        case failed
        /// The app was killed mid-run. Resumable from the thread.
        case interrupted

        var isTerminal: Bool {
            switch self {
            case .approved, .rejected, .done, .failed: true
            default: false
            }
        }

        var isRunning: Bool {
            switch self {
            case .planning, .working: true
            default: false
            }
        }

        var title: String {
            switch self {
            case .planning: "Planning"
            case .working: "Working"
            case .awaitingApproval: "Needs your approval"
            case .approved: "Approved"
            case .rejected: "Rejected"
            case .done: "Done"
            case .failed: "Failed"
            case .interrupted: "Interrupted"
            }
        }

        var symbolName: String {
            switch self {
            case .planning: "wand.and.stars"
            case .working: "gearshape.2.fill"
            case .awaitingApproval: "hand.raised.fill"
            case .approved: "checkmark.seal.fill"
            case .rejected: "xmark.seal.fill"
            case .done: "checkmark.circle.fill"
            case .failed: "exclamationmark.triangle.fill"
            case .interrupted: "pause.circle.fill"
            }
        }
    }

    var id: String
    var botId: String
    /// The user's original ask, kept verbatim so a resumed run has its brief.
    var request: String
    /// Short label the model gives the run, shown as the card's title.
    var title: String
    var steps: [StreamBotRunStep]
    var status: Status
    /// What the bot produced — the draft, the digest, the write-up.
    var result: String?
    /// Why it failed, or why the user rejected it.
    var note: String?
    /// Set when the run was created by another bot handing work over.
    var handedOffBy: String?
    /// Which routine produced this plan, when the run replayed a learned one.
    var routineId: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        botId: String,
        request: String,
        title: String,
        steps: [StreamBotRunStep] = [],
        status: Status = .planning,
        result: String? = nil,
        note: String? = nil,
        handedOffBy: String? = nil,
        routineId: String? = nil
    ) {
        self.id = id
        self.botId = botId
        self.request = request
        self.title = title
        self.steps = steps
        self.status = status
        self.result = result
        self.note = note
        self.handedOffBy = handedOffBy
        self.routineId = routineId
        createdAt = Date()
        updatedAt = Date()
    }

    var activeStep: StreamBotRunStep? {
        steps.first { $0.status == .active } ?? steps.first { $0.status == .pending }
    }

    var completedStepCount: Int {
        steps.filter { $0.status == .done || $0.status == .skipped }.count
    }

    var progress: Double {
        guard !steps.isEmpty else { return status.isTerminal ? 1 : 0 }
        return Double(completedStepCount) / Double(steps.count)
    }

    mutating func touch() { updatedAt = Date() }
}

// MARK: - Message transport

extension StreamBotRun {
    init?(json: String) {
        guard let data = json.data(using: .utf8),
              let decoded = try? Self.decoder.decode(StreamBotRun.self, from: data) else {
            return nil
        }
        self = decoded
    }

    var json: String? {
        guard let data = try? Self.encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// The `extraData` for the message that carries this run. Regenerated on
    /// every edit, which is what keeps the card and the backend in step.
    func messageExtraData(isStreaming: Bool) -> [String: RawJSON] {
        var data: [String: RawJSON] = [
            "grok_kind": .string(StreamBotMessageKind.run.rawValue),
            "grok_streaming": .bool(isStreaming),
            "grok_bot": .string(botId)
        ]
        if let json { data["grok_run"] = .string(json) }
        return data
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

// MARK: - Plain bot messages

enum StreamBotMessagePayload {
    /// `extraData` for a bot's prose reply.
    static func reply(botId: String, isStreaming: Bool) -> [String: RawJSON] {
        [
            "grok_kind": .string(StreamBotMessageKind.reply.rawValue),
            "grok_streaming": .bool(isStreaming),
            "grok_bot": .string(botId)
        ]
    }

    /// `extraData` for one bot handing work to another.
    static func handoff(from: String, to: String) -> [String: RawJSON] {
        [
            "grok_kind": .string(StreamBotMessageKind.handoff.rawValue),
            "grok_bot": .string(from),
            "grok_handoff_to": .string(to)
        ]
    }

    /// `extraData` for the note a bot posts after learning a routine.
    static func routine(botId: String, routineId: String, name: String) -> [String: RawJSON] {
        [
            "grok_kind": .string(StreamBotMessageKind.routine.rawValue),
            "grok_bot": .string(botId),
            "grok_routine": .string(routineId),
            "grok_routine_name": .string(name)
        ]
    }
}
#endif
