#if os(iOS)
// StreamBotTeammate.swift
// The teammate model. A teammate is a persona plus a policy: a lane it works
// in, a set of workspaces it is signed into, and how much it is allowed to
// finish before it comes back to ask.
//
// Bots live in Stream as ordinary chat users — a bot's name, lane, tagline and
// approval policy travel in the Stream user's custom data, so every device
// that connects sees the same roster without a separate backend. Anything the
// model needs but the chat backend does not (system instructions, distilled
// memory, learned routines) is kept on-device in `StreamBotStore`.

import Foundation
import StreamChat
import SwiftUI

// MARK: - Lane

/// The kind of work a bot owns. The lane picks the default instructions and
/// the shape of the plan the model is asked to produce, which is why an Inbox
/// Manager writes triage steps and a Bug Reproduction bot writes repro steps
/// without either being told so in every prompt.
enum StreamBotLane: String, CaseIterable, Identifiable, Sendable, Codable {
    case sales
    case growth
    case recruiting
    case inbox
    case finance
    case success
    case product
    case engineering
    case research
    case coordination

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sales: "Sales"
        case .growth: "Growth"
        case .recruiting: "Recruiting"
        case .inbox: "Inbox"
        case .finance: "Finance"
        case .success: "Customer Success"
        case .product: "Product"
        case .engineering: "Engineering"
        case .research: "Research"
        case .coordination: "Coordination"
        }
    }

    /// What the model is told it does for a living.
    var charter: String {
        switch self {
        case .sales:
            "research accounts, write outbound that sounds like a person, and keep the CRM current"
        case .growth:
            "plan paid campaigns, draft ads in the brand's voice, and park spend changes for review"
        case .recruiting:
            "source candidates, screen them against the role, and draft outreach in the user's voice"
        case .inbox:
            "triage a mailbox, surface what is genuinely urgent, and draft replies"
        case .finance:
            "collect receipts and invoices from portals, code them correctly, and chase what is missing"
        case .success:
            "watch account health, flag risk early, and draft the next touch"
        case .product:
            "read what moved in the product, write the scoreboard, and flag what needs a decision"
        case .engineering:
            "reproduce reported issues and hand engineering a clean, minimal write-up"
        case .research:
            "watch competitors and the market, and report what actually changed"
        case .coordination:
            "route work to the right teammate and keep one clear thread of status"
        }
    }

    /// Verbs used when the model is asked to lay out a plan, so steps read like
    /// the lane rather than like generic task-manager filler.
    var stepVocabulary: String {
        switch self {
        case .sales: "research, qualify, draft, log"
        case .growth: "audit, draft, forecast, park"
        case .recruiting: "source, screen, dedupe, draft"
        case .inbox: "scan, classify, flag, draft"
        case .finance: "sign in, download, code, reconcile"
        case .success: "pull usage, compare, flag, draft"
        case .product: "measure, compare, flag, recommend"
        case .engineering: "reproduce, isolate, capture, write up"
        case .research: "monitor, diff, verify, summarize"
        case .coordination: "split, assign, chase, report"
        }
    }
}

// MARK: - Approval policy

/// How far a bot may go on its own. This is the promise the app makes to the
/// user: `neverSendWithoutApproval` bots physically cannot mark a run finished
/// without a tap, and the runtime enforces it rather than the prompt.
enum StreamBotApprovalPolicy: String, CaseIterable, Identifiable, Sendable, Codable {
    /// Finishes and reports. Used for read-only work.
    case autonomous
    /// Does the work, then parks the result for review.
    case queueUntilApproved
    /// Drafts only. Nothing leaves the app without an explicit approval.
    case neverSendWithoutApproval

    var id: String { rawValue }

    var title: String {
        switch self {
        case .autonomous: "Runs on its own"
        case .queueUntilApproved: "Queues for review"
        case .neverSendWithoutApproval: "Never sends without you"
        }
    }

    var detail: String {
        switch self {
        case .autonomous:
            "Read-only work. Finishes the run and reports back without stopping."
        case .queueUntilApproved:
            "Does the work, then parks the result and waits for your approval."
        case .neverSendWithoutApproval:
            "Drafts only. Nothing is treated as sent until you approve it."
        }
    }

    var symbolName: String {
        switch self {
        case .autonomous: "bolt.fill"
        case .queueUntilApproved: "tray.and.arrow.down.fill"
        case .neverSendWithoutApproval: "hand.raised.fill"
        }
    }

    /// Whether a finished run has to stop for a tap before it counts as done.
    var requiresApproval: Bool { self != .autonomous }
}

// MARK: - Workspace

/// A tool the bot is "signed in to".
///
/// The real Grok Bot logs into vendor portals and ad managers on its own
/// computer. StreamBot runs entirely on device with no browser automation, so
/// a workspace here is a *declared* surface: it tells the planner which system
/// a step happens in, and the UI is explicit that nothing is actually logged
/// into. That keeps the plans concrete without pretending to have access.
enum StreamBotWorkspace: String, CaseIterable, Identifiable, Sendable, Codable {
    case email
    case crm
    case calendar
    case ats
    case vendorPortals
    case issueTracker
    case analytics
    case web
    // The three below are not declared surfaces at all: a plugin backs each one
    // with a real read on this device, and a step is only tagged with one after
    // the bot actually went there. They are in the same enum because the run card
    // and the plan treat "where this step happened" the same way either way.
    case reminders
    case contacts
    case threads

    var id: String { rawValue }

    var title: String {
        switch self {
        case .email: "Email"
        case .crm: "CRM"
        case .calendar: "Calendar"
        case .ats: "ATS"
        case .vendorPortals: "Vendor portals"
        case .issueTracker: "Issue tracker"
        case .analytics: "Analytics"
        case .web: "Web"
        case .reminders: "Reminders"
        case .contacts: "Contacts"
        case .threads: "Threads"
        }
    }

    var symbolName: String {
        switch self {
        case .email: "envelope.fill"
        case .crm: "person.crop.rectangle.stack.fill"
        case .calendar: "calendar"
        case .ats: "doc.text.fill"
        case .vendorPortals: "building.2.fill"
        case .issueTracker: "ladybug.fill"
        case .analytics: "chart.bar.fill"
        case .web: "globe"
        case .reminders: "checklist"
        case .contacts: "person.text.rectangle.fill"
        case .threads: "text.magnifyingglass"
        }
    }

    /// Whether this is a surface the bot can genuinely reach, through a plugin,
    /// rather than one it can only attribute a step to.
    var isLivePluginSurface: Bool {
        switch self {
        case .calendar, .reminders, .contacts, .threads: true
        default: false
        }
    }
}

// MARK: - Bot

struct StreamBotTeammate: Identifiable, Hashable, Sendable {
    /// Stream user id. Also the key for this bot's on-device brain.
    let id: String
    var name: String
    var tagline: String
    var lane: StreamBotLane
    var symbolName: String
    var accent: StreamBotAccent
    var approval: StreamBotApprovalPolicy
    var workspaces: [StreamBotWorkspace]

    /// The bot's short display handle, e.g. "Ada" out of "Ada — Sales Outbound".
    var shortName: String {
        name.split(separator: "—").first?
            .trimmingCharacters(in: .whitespaces) ?? name
    }

    /// The role half of the name, e.g. "Sales Outbound".
    var roleName: String {
        let parts = name.split(separator: "—")
        guard parts.count > 1 else { return lane.title }
        return parts[1].trimmingCharacters(in: .whitespaces)
    }

    var color: Color { accent.color }
}

// MARK: - Reading bots out of Stream

extension StreamBotTeammate {
    /// The marker that separates StreamBot's teammates from every other user
    /// in the Stream app. Set once at seed time and checked on every read.
    static let appMarker = "owngrokbot"

    /// Builds a bot from a Stream user, or returns nil when the user is not one
    /// of this app's teammates.
    init?(user: ChatUser) {
        guard user.extraData["kind"]?.stringValue == "bot",
              user.extraData["app"]?.stringValue == Self.appMarker else {
            return nil
        }
        id = user.id
        name = user.name ?? user.id
        tagline = user.extraData["tagline"]?.stringValue ?? ""
        lane = user.extraData["lane"]?.stringValue
            .flatMap(StreamBotLane.init(rawValue:)) ?? .coordination
        symbolName = user.extraData["symbol"]?.stringValue ?? "sparkles"
        accent = StreamBotAccent(name: user.extraData["accent"]?.stringValue)
        approval = user.extraData["approval"]?.stringValue
            .flatMap(Self.policy(fromSeed:)) ?? .queueUntilApproved
        workspaces = user.extraData["workspaces"]?.stringArrayValue?
            .compactMap(StreamBotWorkspace.init(rawValue:)) ?? lane.defaultWorkspaces
    }

    /// The seeded policy strings use hyphenated names so they read well in the
    /// dashboard; map them onto the enum.
    private static func policy(fromSeed raw: String) -> StreamBotApprovalPolicy? {
        switch raw {
        case "autonomous": .autonomous
        case "queue-until-approved": .queueUntilApproved
        case "never-send-without-approval": .neverSendWithoutApproval
        default: StreamBotApprovalPolicy(rawValue: raw)
        }
    }

    /// The custom-data payload written back to Stream when a bot is created or
    /// edited in the app.
    var streamExtraData: [String: RawJSON] {
        [
            "kind": .string("bot"),
            "app": .string(Self.appMarker),
            "tagline": .string(tagline),
            "symbol": .string(symbolName),
            "accent": .string(accent.rawValue),
            "lane": .string(lane.rawValue),
            "approval": .string(approval.rawValue),
            "workspaces": .array(workspaces.map { .string($0.rawValue) })
        ]
    }
}

extension StreamBotLane {
    /// Sensible starting surfaces for a lane, used when a seeded bot predates
    /// the workspaces field and when the user creates a bot from a preset.
    var defaultWorkspaces: [StreamBotWorkspace] {
        switch self {
        case .sales: [.crm, .email, .web]
        case .growth: [.analytics, .web, .email]
        case .recruiting: [.ats, .email, .web]
        case .inbox: [.email, .calendar]
        case .finance: [.vendorPortals, .email]
        case .success: [.analytics, .crm, .email]
        case .product: [.analytics, .issueTracker, .web]
        case .engineering: [.issueTracker, .web]
        case .research: [.web, .analytics]
        case .coordination: [.email, .calendar, .crm]
        }
    }
}

// MARK: - Accent

/// A fixed palette. Bots are identified by colour throughout the app — in the
/// roster, on the thread row, behind the avatar, and on the run card — so the
/// set is closed and named rather than free-form hex.
///
/// `stream` is the brand blue and the fallback, so a bot seeded with an accent
/// this app no longer offers (the old `purple` and `indigo`) comes back wearing
/// `#005fff` rather than a colour picked at random.
enum StreamBotAccent: String, CaseIterable, Identifiable, Sendable, Codable {
    case stream, orange, cyan, green, teal, pink, red, mint, yellow, brown, navy

    var id: String { rawValue }

    init(name: String?) {
        self = name.flatMap(StreamBotAccent.init(rawValue:)) ?? .stream
    }

    var color: Color {
        switch self {
        case .stream: .streamBot
        case .orange: .orange
        case .cyan: .cyan
        case .green: .green
        case .teal: .teal
        case .pink: .pink
        case .red: .red
        case .mint: .mint
        case .yellow: .yellow
        case .brown: .brown
        case .navy: Color(red: 0.18, green: 0.28, blue: 0.52)
        }
    }
}

// MARK: - Presets

/// The roster offered when creating a bot, mirroring the teammates Grok Bot
/// ships with. Picking one fills in the lane, policy, and workspaces; the user
/// only has to name it.
struct StreamBotPreset: Identifiable, Sendable {
    let id: String
    let name: String
    let role: String
    let tagline: String
    let lane: StreamBotLane
    let symbolName: String
    let accent: StreamBotAccent
    let approval: StreamBotApprovalPolicy

    var displayName: String { "\(name) — \(role)" }

    func makeBot(userId: String) -> StreamBotTeammate {
        StreamBotTeammate(
            id: userId,
            name: displayName,
            tagline: tagline,
            lane: lane,
            symbolName: symbolName,
            accent: accent,
            approval: approval,
            workspaces: lane.defaultWorkspaces
        )
    }

    static let all: [StreamBotPreset] = [
        StreamBotPreset(
            id: "nova",
            name: "Nova",
            role: "Chief of Staff",
            tagline: "Reads what you need, hands it to the right teammate, keeps one thread of status.",
            lane: .coordination,
            symbolName: "person.3.sequence",
            accent: .mint,
            approval: .autonomous
        ),
        StreamBotPreset(
            id: "sales",
            name: "Ada",
            role: "Sales Outbound",
            tagline: "Researches accounts, drafts outreach, updates the CRM.",
            lane: .sales,
            symbolName: "chart.line.uptrend.xyaxis",
            accent: .orange,
            approval: .queueUntilApproved
        ),
        StreamBotPreset(
            id: "paid-media",
            name: "Lumen",
            role: "Paid Media",
            tagline: "Plans campaigns, drafts ads, and parks spend changes until you approve.",
            lane: .growth,
            symbolName: "megaphone.fill",
            accent: .brown,
            approval: .queueUntilApproved
        ),
        StreamBotPreset(
            id: "talent",
            name: "Ravi",
            role: "Talent Scout",
            tagline: "Sources candidates, skips anyone already in the ATS, drafts in your voice.",
            lane: .recruiting,
            symbolName: "person.badge.plus",
            accent: .cyan,
            approval: .queueUntilApproved
        ),
        StreamBotPreset(
            id: "inbox",
            name: "Mira",
            role: "Inbox Manager",
            tagline: "Triages email, flags what is urgent, drafts replies — never sends without you.",
            lane: .inbox,
            symbolName: "tray.full",
            accent: .stream,
            approval: .neverSendWithoutApproval
        ),
        StreamBotPreset(
            id: "expense",
            name: "Otto",
            role: "Expense Manager",
            tagline: "Pulls receipts, codes expenses, chases missing items across portals.",
            lane: .finance,
            symbolName: "creditcard",
            accent: .green,
            approval: .queueUntilApproved
        ),
        StreamBotPreset(
            id: "invoice",
            name: "Juno",
            role: "Invoice Collector",
            tagline: "Logs into vendor portals, downloads invoices, parks them for review.",
            lane: .finance,
            symbolName: "doc.text.magnifyingglass",
            accent: .teal,
            approval: .queueUntilApproved
        ),
        StreamBotPreset(
            id: "account",
            name: "Sable",
            role: "Account Health",
            tagline: "Digests, risk flags, and next-step drafts so accounts stay warm.",
            lane: .success,
            symbolName: "heart.text.square",
            accent: .pink,
            approval: .queueUntilApproved
        ),
        StreamBotPreset(
            id: "product",
            name: "Reed",
            role: "Product Performance",
            tagline: "Reads what moved, writes the scoreboard, and flags the decision that is due.",
            lane: .product,
            symbolName: "speedometer",
            accent: .navy,
            approval: .autonomous
        ),
        StreamBotPreset(
            id: "bugs",
            name: "Pike",
            role: "Bug Reproduction",
            tagline: "Recreates issues and hands engineering a clean write-up.",
            lane: .engineering,
            symbolName: "ladybug",
            accent: .red,
            approval: .autonomous
        ),
        StreamBotPreset(
            id: "compete",
            name: "Vesper",
            role: "Competitive Intel",
            tagline: "Overnight watch for launches and stale messaging.",
            lane: .research,
            symbolName: "binoculars",
            accent: .yellow,
            approval: .autonomous
        )
    ]
}
#endif
