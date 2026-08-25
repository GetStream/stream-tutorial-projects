#if os(iOS)
// StreamBotPlugin.swift
// The plugin catalogue: what the marketplace sells, and what installing one
// actually does to a teammate.
//
// Grok Bot's plugins bundle two different things behind one Add button — skills
// (instructions for how to do a job) and connectors (access to a system the bot
// can read or act in). This app keeps that shape, and takes the second half
// literally rather than decoratively: a connector here is a real on-device
// source exposed to the model as a FoundationModels `Tool`, so a bot with the
// Calendar plugin reads the actual calendar instead of describing one.
//
// Nothing in the catalogue is a placeholder. If a plugin is listed, adding it
// changes what the bots can do — which is why the list is short. There is no
// Gmail plugin, because shipping one would mean pretending to a mailbox the app
// has no route to.

import Foundation

// MARK: - Skill

/// A named way of working, installed by a plugin.
///
/// A skill is instructions, not code: the steps, the shape of the output, and
/// the boundaries. It is added to the bot's system prompt when the request looks
/// like the work it describes, and can be invoked by name from the composer with
/// `/`, which is how the app makes an instruction package feel like a command.
struct StreamBotSkill: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// One line, shown in the `/` menu and on the plugin's page.
    let summary: String
    /// What kind of request this is for, matched against what the user asked.
    let trigger: String
    /// The instructions themselves.
    let instructions: String
}

// MARK: - Connector

/// An on-device source a plugin opens up.
///
/// Each case is backed by a real tool in `StreamBotPluginTools` and a real
/// framework: EventKit, Contacts, Stream's own search, or the clock. The user's
/// data never leaves the phone to be read — the model runs here, and so does
/// the read.
enum StreamBotConnector: String, Identifiable, CaseIterable, Sendable {
    case calendar
    case reminders
    case contacts
    case threads
    case clock

    var id: String { rawValue }

    /// What the bot can do with it, in the user's terms.
    var summary: String {
        switch self {
        case .calendar:
            "Reads your events for a day or a range, with times and attendee counts."
        case .reminders:
            "Reads your open reminders and when they are due."
        case .contacts:
            "Looks up a person you know by name, and their work details."
        case .threads:
            "Searches everything said in your StreamBot threads."
        case .clock:
            "Answers what today's date is and does date arithmetic."
        }
    }

    /// Read-only, every one of them. Writing to a calendar or a contact card is
    /// the kind of side effect this app's approval model exists to prevent, and a
    /// bot that can only read cannot quietly change the user's week.
    var isReadOnly: Bool { true }

    var permission: StreamBotPluginPermission {
        switch self {
        case .calendar: .calendar
        case .reminders: .reminders
        case .contacts: .contacts
        case .threads, .clock: .none
        }
    }

    /// The surface a step gets attributed to when this connector was used in it.
    var surface: StreamBotWorkspace? {
        switch self {
        case .calendar: .calendar
        case .reminders: .reminders
        case .contacts: .contacts
        case .threads: .threads
        case .clock: nil
        }
    }

    /// The tool name the model calls. Also what the run card credits.
    var toolName: String {
        switch self {
        case .calendar: "readCalendar"
        case .reminders: "readReminders"
        case .contacts: "findContact"
        case .threads: "searchThreads"
        case .clock: "resolveDate"
        }
    }
}

// MARK: - Permission

/// The system permission a connector needs before it can read anything.
///
/// Asked for at Add time rather than mid-run. A bot that stops halfway through a
/// plan to ask for calendar access has already wasted the user's attention, and
/// the marketplace is where the user is already deciding to grant something.
enum StreamBotPluginPermission: Sendable {
    case none
    case calendar
    case reminders
    case contacts

    var title: String? {
        switch self {
        case .none: nil
        case .calendar: "Calendar access"
        case .reminders: "Reminders access"
        case .contacts: "Contacts access"
        }
    }
}

// MARK: - Category

enum StreamBotPluginCategory: String, CaseIterable, Identifiable, Sendable {
    case connectors
    case skills

    var id: String { rawValue }

    var title: String {
        switch self {
        case .connectors: "Device connectors"
        case .skills: "Packaged skills"
        }
    }

    var detail: String {
        switch self {
        case .connectors:
            "Real sources on this phone. The bot reads them during a run; nothing is uploaded."
        case .skills:
            "Instructions, not access. Any bot can use these without granting anything."
        }
    }
}

// MARK: - Plugin

struct StreamBotPlugin: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let tagline: String
    let symbolName: String
    let accent: StreamBotAccent
    let category: StreamBotPluginCategory
    let isFeatured: Bool
    let skills: [StreamBotSkill]
    let connector: StreamBotConnector?
    /// Lanes this is switched on for the moment it is added, so a Calendar
    /// plugin is live for the Chief of Staff without the user visiting nine bots.
    let suggestedLanes: [StreamBotLane]

    var permission: StreamBotPluginPermission { connector?.permission ?? .none }

    static func == (lhs: StreamBotPlugin, rhs: StreamBotPlugin) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Catalogue

enum StreamBotPluginCatalog {
    static let all: [StreamBotPlugin] = [
        calendar, reminders, contacts, threads, clock,
        meetingNotes, bugReports, coldOutreach, weeklyReview, accountDigest,
        paidMedia, productPerformance
    ]

    static var featured: [StreamBotPlugin] { all.filter(\.isFeatured) }

    static func plugins(in category: StreamBotPluginCategory) -> [StreamBotPlugin] {
        all.filter { $0.category == category }
    }

    static func plugin(id: String) -> StreamBotPlugin? {
        all.first { $0.id == id }
    }

    static func plugin(for connector: StreamBotConnector) -> StreamBotPlugin? {
        all.first { $0.connector == connector }
    }

    // MARK: Connectors

    static let calendar = StreamBotPlugin(
        id: "calendar",
        name: "Calendar",
        tagline: "Your real events, so a plan lands on a day that exists.",
        symbolName: "calendar",
        accent: .red,
        category: .connectors,
        isFeatured: true,
        skills: [
            StreamBotSkill(
                id: "calendar.dayBrief",
                name: "Day brief",
                summary: "What today looks like and where the gaps are.",
                trigger: "the user asks about their day, week, schedule, or when they are free",
                instructions: """
                    Read the calendar before saying anything about the user's time. \
                    Report the day as: what is fixed, where the real gaps are, and the \
                    one thing most likely to overrun. Give times in the user's own \
                    timezone. Never invent a meeting that is not in the calendar — if \
                    the day is empty, say it is empty.
                    """
            ),
            StreamBotSkill(
                id: "calendar.meetingPrep",
                name: "Meeting prep",
                summary: "A brief for the next meeting on the calendar.",
                trigger: "the user asks to prepare for a meeting, call, review, or interview",
                instructions: """
                    Find the meeting in the calendar first, then prepare for the one \
                    that is actually next unless the user named another. Produce: what \
                    it is for, who is in it, what you would need to have ready, and the \
                    questions worth asking. Keep it to what fits on a phone screen \
                    before the meeting starts.
                    """
            )
        ],
        connector: .calendar,
        suggestedLanes: [.coordination, .inbox, .success, .sales]
    )

    static let reminders = StreamBotPlugin(
        id: "reminders",
        name: "Reminders",
        tagline: "What you already said you would do, before it gets re-planned.",
        symbolName: "checklist",
        accent: .orange,
        category: .connectors,
        isFeatured: false,
        skills: [
            StreamBotSkill(
                id: "reminders.whatsOpen",
                name: "What's open",
                summary: "Overdue and due-soon, sorted by what actually slips.",
                trigger: "the user asks what is outstanding, overdue, on their list, or what to do next",
                instructions: """
                    Read the open reminders before deciding what matters. Lead with \
                    what is overdue, then what is due today. Group the rest only if \
                    there are more than six. Do not restate the whole list back — the \
                    user can already see it; say what to do first and why.
                    """
            )
        ],
        connector: .reminders,
        suggestedLanes: [.coordination, .inbox, .finance]
    )

    static let contacts = StreamBotPlugin(
        id: "contacts",
        name: "Contacts",
        tagline: "Who someone is, so outreach uses their real name and company.",
        symbolName: "person.text.rectangle",
        accent: .cyan,
        category: .connectors,
        isFeatured: true,
        skills: [
            StreamBotSkill(
                id: "contacts.lookUp",
                name: "Look someone up",
                summary: "Pull a person's details before writing to or about them.",
                trigger: "the user names a person to contact, brief, or write to",
                instructions: """
                    Look the person up before drafting anything addressed to them, and \
                    use the details you find: their actual name as they spell it, their \
                    company, their role. If they are not in contacts, say so and write \
                    the draft without inventing an employer or a title.
                    """
            )
        ],
        connector: .contacts,
        suggestedLanes: [.sales, .recruiting, .inbox, .success]
    )

    static let threads = StreamBotPlugin(
        id: "threads",
        name: "Threads",
        tagline: "Search everything your team of bots has already said.",
        symbolName: "text.magnifyingglass",
        accent: .stream,
        category: .connectors,
        isFeatured: true,
        skills: [
            StreamBotSkill(
                id: "threads.whatWasSaid",
                name: "What was said",
                summary: "Find the earlier answer instead of producing a new one.",
                trigger: "the user refers to something discussed before, or asks what a teammate said or decided",
                instructions: """
                    Search the threads before answering anything that starts with \
                    "what did", "didn't we", or "earlier". Quote the line you found and \
                    say which teammate said it. If the search comes back empty, say the \
                    thread does not contain it rather than reconstructing it from \
                    memory.
                    """
            )
        ],
        connector: .threads,
        suggestedLanes: StreamBotLane.allCases
    )

    static let clock = StreamBotPlugin(
        id: "clock",
        name: "Clock & Dates",
        tagline: "Today's real date, and date maths the model doesn't have to guess.",
        symbolName: "clock",
        accent: .mint,
        category: .connectors,
        isFeatured: false,
        skills: [],
        connector: .clock,
        suggestedLanes: StreamBotLane.allCases
    )

    // MARK: Packaged skills

    static let meetingNotes = StreamBotPlugin(
        id: "meeting-notes",
        name: "Meeting Notes",
        tagline: "Turns a messy transcript into decisions and owners.",
        symbolName: "text.append",
        accent: .teal,
        category: .skills,
        isFeatured: true,
        skills: [
            StreamBotSkill(
                id: "notes.writeUp",
                name: "Meeting write-up",
                summary: "Decisions, owners, and open questions — in that order.",
                trigger: "the user pastes or refers to notes, a transcript, or a recording of a meeting",
                instructions: """
                    Write the notes in four parts and nothing else: Decisions (what was \
                    settled), Owners (name — what they took, by when), Open (what was \
                    raised and not resolved), and Next (the first thing that has to \
                    happen). Attribute an action only to someone who accepted it. If \
                    nobody owns something, put it under Open rather than assigning it.
                    """
            )
        ],
        connector: nil,
        suggestedLanes: [.coordination, .success, .engineering]
    )

    static let bugReports = StreamBotPlugin(
        id: "bug-reports",
        name: "Bug Reports",
        tagline: "Repro steps first, opinions last.",
        symbolName: "ladybug",
        accent: .red,
        category: .skills,
        isFeatured: false,
        skills: [
            StreamBotSkill(
                id: "bugs.writeUp",
                name: "Clean repro",
                summary: "A write-up an engineer can act on without a reply.",
                trigger: "the user reports something broken, crashing, failing, or behaving unexpectedly",
                instructions: """
                    Structure it as: Environment, Steps (numbered, each one a single \
                    action), Expected, Actual, and Evidence. Keep every step something a \
                    stranger could follow. Separate what was observed from what you \
                    infer, and label the inference. If a step cannot be reproduced from \
                    what the user gave you, say which one is missing instead of \
                    guessing it.
                    """
            )
        ],
        connector: nil,
        suggestedLanes: [.engineering, .success]
    )

    static let coldOutreach = StreamBotPlugin(
        id: "cold-outreach",
        name: "Cold Outreach",
        tagline: "Short, specific, and sounds like a person wrote it.",
        symbolName: "paperplane",
        accent: .orange,
        category: .skills,
        isFeatured: false,
        skills: [
            StreamBotSkill(
                id: "outreach.firstTouch",
                name: "First touch",
                summary: "Under 90 words, one ask, no adjectives.",
                trigger: "the user asks for outbound, a cold email, a first touch, or candidate outreach",
                instructions: """
                    Under 90 words. Open with the specific reason you are writing to \
                    this person — something true about them, not about you. One ask, and \
                    make it small. No adjectives about your own product, no "hope this \
                    finds you well", no three-paragraph value props. End with a question \
                    they can answer in one line.
                    """
            ),
            StreamBotSkill(
                id: "outreach.followUp",
                name: "Follow-up",
                summary: "A nudge that adds something instead of repeating.",
                trigger: "the user asks to follow up, chase, or bump a thread",
                instructions: """
                    A follow-up has to carry something new: a relevant change, a shorter \
                    ask, or an easy out. Never re-send the pitch and never mention that \
                    you are following up for the second time. Three sentences at most.
                    """
            )
        ],
        connector: nil,
        suggestedLanes: [.sales, .growth, .recruiting]
    )

    static let weeklyReview = StreamBotPlugin(
        id: "weekly-review",
        name: "Weekly Review",
        tagline: "A status digest that leads with what changed.",
        symbolName: "chart.line.uptrend.xyaxis",
        accent: .green,
        category: .skills,
        isFeatured: false,
        skills: [
            StreamBotSkill(
                id: "review.digest",
                name: "Weekly digest",
                summary: "Changed, stuck, next — nothing else.",
                trigger: "the user asks for a weekly summary, a status update, a digest, or a review",
                instructions: """
                    Three sections: Changed (what moved, with the number if there is \
                    one), Stuck (what did not, and what it is waiting on), Next (what you \
                    will do without being asked). Lead with the item the user would be \
                    annoyed to discover late. No preamble and no closing summary.
                    """
            )
        ],
        connector: nil,
        suggestedLanes: [.coordination, .success, .research, .finance, .product]
    )

    static let accountDigest = StreamBotPlugin(
        id: "account-digest",
        name: "Account Health",
        tagline: "Risk flags with the evidence attached.",
        symbolName: "heart.text.square",
        accent: .pink,
        category: .skills,
        isFeatured: false,
        skills: [
            StreamBotSkill(
                id: "accounts.risk",
                name: "Risk read",
                summary: "Churn and expansion signals, ranked, with the reason.",
                trigger: "the user asks about account health, churn, renewal risk, or expansion",
                instructions: """
                    For each account: the signal, the evidence behind it, and how \
                    confident you are. Rank by how soon someone has to act, not by \
                    account size. Say plainly when a read is based on something you \
                    cannot see — no confident percentages built on nothing.
                    """
            )
        ],
        connector: nil,
        suggestedLanes: [.success, .sales]
    )

    static let paidMedia = StreamBotPlugin(
        id: "paid-media",
        name: "Paid Media",
        tagline: "Campaign plans and ad drafts that wait for a yes before spend moves.",
        symbolName: "megaphone.fill",
        accent: .brown,
        category: .skills,
        isFeatured: true,
        skills: [
            StreamBotSkill(
                id: "ads.brief",
                name: "Campaign brief",
                summary: "Audience, offer, three ad angles, and a budget you have not spent.",
                trigger: "the user asks for ads, a campaign, paid media, creatives, or a media plan",
                instructions: """
                    Produce: the audience in one sentence, the offer, three distinct \
                    angles with a headline and a 30-word body each, and the budget as a \
                    recommendation — never as something already spent. Flag anything that \
                    would need a live ad account. Do not invent performance numbers.
                    """
            )
        ],
        connector: nil,
        suggestedLanes: [.growth, .sales]
    )

    static let productPerformance = StreamBotPlugin(
        id: "product-performance",
        name: "Product Performance",
        tagline: "A scoreboard that leads with the decision, not the chart.",
        symbolName: "speedometer",
        accent: .navy,
        category: .skills,
        isFeatured: false,
        skills: [
            StreamBotSkill(
                id: "product.scoreboard",
                name: "Scoreboard",
                summary: "What moved, what it means, and the one decision due.",
                trigger: "the user asks for product metrics, a scoreboard, activation, retention, or what shipped",
                instructions: """
                    Three parts: Moved (the number and the window), Means (what a person \
                    should believe now that they did not last week), Decision (the one \
                    call that is due, with the default if nobody decides). Never pad with \
                    vanity metrics, and never invent a chart the user did not give you.
                    """
            )
        ],
        connector: nil,
        suggestedLanes: [.product, .coordination, .success]
    )
}
#endif
