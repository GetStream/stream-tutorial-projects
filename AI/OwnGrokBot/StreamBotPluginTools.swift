#if os(iOS)
// StreamBotPluginTools.swift
// The connectors, as tools the model can actually call.
//
// This is the half of the plugin system that does work. Each type here is a
// FoundationModels `Tool`: the session is handed the ones the teammate has
// switched on, the model decides mid-generation that it needs one, and the read
// happens on this device against a real framework — EventKit, Contacts, Stream's
// own search, the system calendar. No network leaves the phone for any of it
// except the thread search, which goes to the same Stream connection the app is
// already holding open.
//
// Three rules hold everywhere in this file:
//
//   * Read-only. Nothing here creates, edits, or deletes anything the user owns.
//   * Small answers. A tool result is prompt tokens on a phone-sized model, so
//     every one of these is capped and formatted as lines rather than dumped.
//   * Honest emptiness. "No events" and "no access" are different answers and
//     both are said plainly, because a model handed nothing will otherwise
//     invent something plausible.

import Contacts
import EventKit
import Foundation
import FoundationModels
import StreamChat

// MARK: - Use log

/// Which connectors were touched, so the run card can credit them.
///
/// A tool call is invisible by design — it happens inside `respond`, between the
/// prompt and the answer. That is exactly the thing this app refuses to hide: the
/// point of the run card is that the user can see where the work went. Each tool
/// records itself here, and the engine reads the log after every step to tag it
/// with the surface the bot really visited.
@MainActor
final class StreamBotToolLog {
    static let shared = StreamBotToolLog()
    private var used: Set<StreamBotConnector> = []

    private init() {}

    func record(_ connector: StreamBotConnector) { used.insert(connector) }

    /// Returns what has been used since the last call and starts over.
    func drain() -> [StreamBotConnector] {
        let all = used
        used = []
        return Array(all)
    }
}

// MARK: - Factory

enum StreamBotPluginToolbox {
    /// The tools for one teammate's enabled connectors.
    static func tools(for connectors: [StreamBotConnector]) -> [any Tool] {
        connectors.map { connector in
            switch connector {
            case .calendar: StreamBotCalendarTool()
            case .reminders: StreamBotRemindersTool()
            case .contacts: StreamBotContactsTool()
            case .threads: StreamBotThreadSearchTool()
            case .clock: StreamBotClockTool()
            }
        }
    }
}

// MARK: - EventKit

/// One EventKit store, always used on the main actor.
///
/// A fresh `EKEventStore()` created at tool-call time looks authorized
/// (`.fullAccess`) but often has an empty `calendars(for:)` snapshot on a
/// real iPhone — especially after the permission prompt was handled by a
/// different instance. EventKit caches that snapshot on the object that was
/// alive when access was `.notDetermined`. Rebuilding the store after a grant,
/// then reading from that instance, is what actually returns iCloud / Google /
/// Exchange events.
@MainActor
final class StreamBotEventKit {
    static let shared = StreamBotEventKit()

    private var store = EKEventStore()

    private init() {}

    /// Drops the instance that may have been created before access was granted
    /// and pulls sources so iCloud calendars are actually present.
    func rebuild() {
        store = EKEventStore()
        store.refreshSourcesIfNecessary()
    }

    var hasEventAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    var hasReminderAccess: Bool {
        EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }

    func requestEventAccess() async -> Bool {
        let granted: Bool
        if hasEventAccess {
            granted = true
        } else {
            granted = (try? await store.requestFullAccessToEvents()) ?? false
        }
        rebuild()
        return granted
    }

    func requestReminderAccess() async -> Bool {
        let granted: Bool
        if hasReminderAccess {
            granted = true
        } else {
            granted = (try? await store.requestFullAccessToReminders()) ?? false
        }
        rebuild()
        return granted
    }

    /// Events in `[start, end)`, from every event calendar the app can see.
    func events(from start: Date, to end: Date) -> CalendarRead {
        store.refreshSourcesIfNecessary()
        var calendars = store.calendars(for: .event)
        if calendars.isEmpty {
            rebuild()
            calendars = store.calendars(for: .event)
        }
        guard !calendars.isEmpty else {
            return .noCalendars
        }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let events = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
        return .ok(calendars: calendars, events: events)
    }

    func incompleteReminders() async -> [EKReminder] {
        store.refreshSourcesIfNecessary()
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )
        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { continuation.resume(returning: $0 ?? []) }
        }
    }

    enum CalendarRead {
        case noCalendars
        case ok(calendars: [EKCalendar], events: [EKEvent])
    }
}

// MARK: - Calendar

struct StreamBotCalendarTool: Tool {
    let name = StreamBotConnector.calendar.toolName
    let description = """
        Read the user's real calendar events. Call this before saying anything \
        about their schedule, availability, or a meeting. For today use \
        startDayOffset 0 and dayCount 1. For this week, or when they did not \
        name a day, use startDayOffset 0 and dayCount 7.
        """

    @Generable
    struct Arguments {
        @Guide(description: "Days from today to start at. 0 is today, 1 is tomorrow.")
        var startDayOffset: Int
        @Guide(description: "How many days to read. 1 is one day, 7 is a week. Use 7 when the user did not name a specific day.")
        var dayCount: Int
    }

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            StreamBotToolLog.shared.record(.calendar)
            return StreamBotEventKit.shared.readSchedule(
                startDayOffset: arguments.startDayOffset,
                dayCount: arguments.dayCount
            )
        }
    }
}

extension StreamBotEventKit {
    func readSchedule(startDayOffset: Int, dayCount: Int) -> String {
        guard hasEventAccess else {
            return "No calendar access was granted, so the schedule could not be read. Turn Calendar on in Settings → StreamBot."
        }

        let calendar = Calendar.current
        // 0 from the model means "unspecified", not "zero days". A one-day
        // window on an empty today is how "no events" was reported on a phone
        // with a full week.
        let offset = max(-365, min(365, startDayOffset))
        let days = dayCount <= 0 ? 7 : max(1, min(14, dayCount))
        let start = calendar.date(
            byAdding: .day,
            value: offset,
            to: calendar.startOfDay(for: Date())
        ) ?? Date()
        var end = calendar.date(byAdding: .day, value: days, to: start) ?? start

        var read = events(from: start, to: end)
        var widened = false
        if case .ok(_, let first) = read, first.isEmpty, days < 7 {
            end = calendar.date(byAdding: .day, value: 7, to: start) ?? end
            read = events(from: start, to: end)
            widened = true
        }

        switch read {
        case .noCalendars:
            return "Calendar access is on, but no calendars are visible on this phone. In Settings → StreamBot → Calendars, choose Full Access (not Add Events Only) and include the calendars that hold the events."
        case .ok(let calendars, let events):
            let names = calendars.map(\.title).sorted().joined(separator: ", ")
            guard !events.isEmpty else {
                return "No events between \(Self.day.string(from: start)) and \(Self.day.string(from: end)) across \(calendars.count) calendars (\(names))."
            }
            let header = widened
                ? "Nothing on \(Self.day.string(from: start)). Upcoming this week:\n"
                : ""
            let lines = events.prefix(24).map { event in
                var line = "\(Self.day.string(from: event.startDate))"
                if event.isAllDay {
                    line += ", all day"
                } else {
                    line += " \(Self.time.string(from: event.startDate))–\(Self.time.string(from: event.endDate))"
                }
                line += ": \(event.title ?? "Untitled")"
                if let calendarName = event.calendar?.title, !calendarName.isEmpty {
                    line += " [\(calendarName)]"
                }
                if let location = event.location, !location.isEmpty {
                    line += " (at \(location))"
                }
                if let attendees = event.attendees, attendees.count > 1 {
                    line += " [\(attendees.count) people]"
                }
                return line
            }
            return header + lines.joined(separator: "\n")
        }
    }

    private static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter
    }()

    private static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

// MARK: - Reminders

struct StreamBotRemindersTool: Tool {
    let name = StreamBotConnector.reminders.toolName
    let description = """
        Read the user's open reminders with their due dates. Call this before \
        deciding what is outstanding or what they should do next.
        """

    @Generable
    struct Arguments {
        @Guide(description: "Only reminders due within this many days. Use 0 for all open reminders.")
        var withinDays: Int
    }

    func call(arguments: Arguments) async throws -> String {
        await readOnMain(withinDays: arguments.withinDays)
    }

    @MainActor
    private func readOnMain(withinDays: Int) async -> String {
        StreamBotToolLog.shared.record(.reminders)
        return await StreamBotEventKit.shared.readReminders(withinDays: withinDays)
    }
}

extension StreamBotEventKit {
    func readReminders(withinDays: Int) async -> String {
        guard hasReminderAccess else {
            return "No reminders access was granted, so the list could not be read."
        }
        let reminders = await incompleteReminders()
        guard !reminders.isEmpty else { return "No open reminders." }

        let cutoff = withinDays > 0
            ? Calendar.current.date(byAdding: .day, value: min(90, withinDays), to: Date())
            : nil
        let now = Date()
        let lines = reminders
            .compactMap { reminder -> (due: Date?, text: String)? in
                let due = reminder.dueDateComponents.flatMap(Calendar.current.date(from:))
                if let cutoff, let due, due > cutoff { return nil }
                if cutoff != nil, due == nil { return nil }
                var text = reminder.title ?? "Untitled"
                if let due {
                    text += due < now
                        ? " — overdue, was due \(Self.due.string(from: due))"
                        : " — due \(Self.due.string(from: due))"
                } else {
                    text += " — no due date"
                }
                return (due, text)
            }
            .sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
            .prefix(20)
            .map(\.text)

        guard !lines.isEmpty else { return "Nothing due in that window." }
        return lines.joined(separator: "\n")
    }

    private static let due: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter
    }()
}

// MARK: - Contacts

struct StreamBotContactsTool: Tool {
    let name = StreamBotConnector.contacts.toolName
    let description = """
        Look up a person in the user's contacts by name, to get how their name is \
        spelled, their company, their role, and their email.
        """

    @Generable
    struct Arguments {
        @Guide(description: "The person's name, or part of it.")
        var name: String
    }

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { StreamBotToolLog.shared.record(.contacts) }
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited:
            break
        default:
            return "No contacts access was granted, so \(arguments.name) could not be looked up."
        }
        let query = arguments.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return "Give a name of at least two characters." }

        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]
        let matches = try store.unifiedContacts(
            matching: CNContact.predicateForContacts(matchingName: query),
            keysToFetch: keys
        )
        guard !matches.isEmpty else {
            return "Nobody called \(query) is in contacts."
        }

        return matches.prefix(4).map { contact in
            var line = CNContactFormatter.string(from: contact, style: .fullName) ?? query
            if !contact.jobTitle.isEmpty { line += ", \(contact.jobTitle)" }
            if !contact.organizationName.isEmpty { line += " at \(contact.organizationName)" }
            if let email = contact.emailAddresses.first?.value as String? {
                line += " — \(email)"
            }
            return line
        }
        .joined(separator: "\n")
    }
}

// MARK: - Threads

struct StreamBotThreadSearchTool: Tool {
    let name = StreamBotConnector.threads.toolName
    let description = """
        Search what has already been said in the user's StreamBot threads, \
        including by other teammates. Call this for anything the user refers to as \
        earlier, previous, or already discussed.
        """

    @Generable
    struct Arguments {
        @Guide(description: "The words to search for. Keep it to two or three.")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { StreamBotToolLog.shared.record(.threads) }
        let query = arguments.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return "Give at least two characters to search for." }

        let results = try await Self.search(query)
        guard !results.isEmpty else {
            return "Nothing in the threads mentions \"\(query)\"."
        }
        return results.joined(separator: "\n")
    }

    /// The search itself, on the main actor: the user's client and the roster both
    /// live there, and the tool is called from the model's own executor.
    @MainActor
    private static func search(_ query: String) async throws -> [String] {
        guard let client = StreamBotChatService.shared.chatClient else {
            throw StreamBotError("The chat connection is not up, so the threads could not be searched.")
        }
        let controller = client.messageSearchController()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            controller.search(text: query) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        let roster = StreamBotRoster.shared.byId
        return controller.messages
            .prefix(8)
            .map { message in
                let who = roster[message.author.id]?.shortName
                    ?? (message.author.id == StreamBotCredentials.userId ? "You" : message.author.name ?? message.author.id)
                let text = message.text
                    .replacingOccurrences(of: "\n", with: " ")
                    .prefix(220)
                return "\(who), \(Self.when.string(from: message.createdAt)): \(text)"
            }
    }

    private static let when: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()
}

// MARK: - Clock

/// The smallest plugin in the catalogue, and the one that prevents the most
/// nonsense. A model has no clock: asked to plan "by Thursday" it will invent a
/// date, and every date after that in the plan is wrong too.
struct StreamBotClockTool: Tool {
    let name = StreamBotConnector.clock.toolName
    let description = """
        Get the real current date and time, or the date a number of days from \
        today. Call this before using any date in a plan or a draft.
        """

    @Generable
    struct Arguments {
        @Guide(description: "Days from today. 0 is today, 7 is a week from today, -1 is yesterday.")
        var dayOffset: Int
    }

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run { StreamBotToolLog.shared.record(.clock) }
        let calendar = Calendar.current
        let offset = max(-365, min(365, arguments.dayOffset))
        let date = calendar.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM yyyy"
        var answer = formatter.string(from: date)
        if offset == 0 {
            let time = DateFormatter()
            time.timeStyle = .short
            time.dateStyle = .none
            answer += ", \(time.string(from: date)) \(TimeZone.current.identifier)"
        }
        return answer
    }
}
#endif
