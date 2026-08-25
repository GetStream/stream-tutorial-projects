#if os(iOS)
// StreamBotStore.swift
// The part of a bot that never leaves the device: its system instructions, the
// routines it has been taught, and the preferences it has remembered about how
// the user likes things done.
//
// This is deliberately separate from the Stream user record. The roster is
// shared state — a name, a lane, a colour, worth syncing. Memory is not: it is
// the user's own working habits, distilled from their own messages by a model
// running on their own phone, and it stays in the app container.
//
// Everything here is small text and is written as one JSON file per concern, so
// a corrupt write costs a routine list rather than the whole app.

import Foundation
import Observation

// MARK: - Routine

/// A workflow the bot learned by watching once.
///
/// Grok Bot's pitch is "show a Bot how it's done" — you complete the work in
/// the thread, the bot distils the steps, and next time it runs them itself.
/// A routine is that distillation: a name, the conditions it applies to, and
/// the ordered steps, all produced by the on-device model from the real
/// conversation rather than typed in by the user.
struct StreamBotRoutine: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var botId: String
    var name: String
    /// When this routine should be used, in the model's words. Matched against
    /// new requests so a routine fires without the user naming it.
    var trigger: String
    var steps: [String]
    /// The corrections the user made while teaching, kept because they are the
    /// part the bot is most likely to get wrong again.
    var corrections: [String]
    var createdAt: Date
    var runCount: Int
    /// Off means the routine still exists but will not match or fire on a schedule.
    var isEnabled: Bool
    /// Hour of day (0–23) in the Settings timezone. Nil means unscheduled.
    var scheduleHour: Int?
    var lastScheduledFire: Date?

    enum CodingKeys: String, CodingKey {
        case id, botId, name, trigger, steps, corrections, createdAt, runCount
        case isEnabled, scheduleHour, lastScheduledFire
    }

    init(
        id: String = UUID().uuidString,
        botId: String,
        name: String,
        trigger: String,
        steps: [String],
        corrections: [String] = [],
        isEnabled: Bool = true,
        scheduleHour: Int? = nil,
        lastScheduledFire: Date? = nil
    ) {
        self.id = id
        self.botId = botId
        self.name = name
        self.trigger = trigger
        self.steps = steps
        self.corrections = corrections
        createdAt = Date()
        runCount = 0
        self.isEnabled = isEnabled
        self.scheduleHour = scheduleHour
        self.lastScheduledFire = lastScheduledFire
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        botId = try container.decode(String.self, forKey: .botId)
        name = try container.decode(String.self, forKey: .name)
        trigger = try container.decode(String.self, forKey: .trigger)
        steps = try container.decode([String].self, forKey: .steps)
        corrections = try container.decodeIfPresent([String].self, forKey: .corrections) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        runCount = try container.decodeIfPresent(Int.self, forKey: .runCount) ?? 0
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        scheduleHour = try container.decodeIfPresent(Int.self, forKey: .scheduleHour)
        lastScheduledFire = try container.decodeIfPresent(Date.self, forKey: .lastScheduledFire)
    }

    var scheduleLabel: String? {
        guard let scheduleHour else { return nil }
        let hour = scheduleHour % 24
        let suffix = hour >= 12 ? "PM" : "AM"
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        return "Daily at \(twelve):00 \(suffix)"
    }
}

// MARK: - Memory

/// One thing the bot remembers about how the user works.
struct StreamBotMemory: Identifiable, Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        /// A standing preference: tone, format, who to copy.
        case preference
        /// A fact about the user's world: team names, tools, accounts.
        case fact
        /// Something the bot got wrong and was corrected on.
        case correction

        var symbolName: String {
            switch self {
            case .preference: "slider.horizontal.3"
            case .fact: "info.circle"
            case .correction: "arrow.uturn.backward.circle"
            }
        }

        var title: String {
            switch self {
            case .preference: "Preference"
            case .fact: "Context"
            case .correction: "Correction"
            }
        }
    }

    var id: String
    var botId: String
    var kind: Kind
    var text: String
    var createdAt: Date

    init(id: String = UUID().uuidString, botId: String, kind: Kind, text: String) {
        self.id = id
        self.botId = botId
        self.kind = kind
        self.text = text
        createdAt = Date()
    }
}

// MARK: - Instructions

/// Per-bot system prompt overrides. Empty means "use the lane's default", which
/// is the common case — most users never open this.
struct StreamBotInstructions: Codable, Hashable, Sendable {
    var botId: String
    var custom: String

    var isEmpty: Bool {
        custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Store

@MainActor
@Observable
final class StreamBotStore {
    static let shared = StreamBotStore()

    private(set) var routines: [StreamBotRoutine] = []
    private(set) var memories: [StreamBotMemory] = []
    private(set) var instructions: [String: StreamBotInstructions] = [:]

    /// Bots the user created in the app. Seeded bots come from Stream; these are
    /// tracked locally too so the roster survives a cold start before the
    /// channel list has synchronised.
    private(set) var locallyCreatedBotIds: Set<String> = []

    private init() {
        routines = Self.load([StreamBotRoutine].self, from: .routines) ?? []
        memories = Self.load([StreamBotMemory].self, from: .memories) ?? []
        let stored = Self.load([StreamBotInstructions].self, from: .instructions) ?? []
        instructions = Dictionary(uniqueKeysWithValues: stored.map { ($0.botId, $0) })
        locallyCreatedBotIds = Set(Self.load([String].self, from: .createdBots) ?? [])
    }

    // MARK: Routines

    func routines(for botId: String) -> [StreamBotRoutine] {
        routines.filter { $0.botId == botId }.sorted { $0.createdAt > $1.createdAt }
    }

    func add(_ routine: StreamBotRoutine) {
        routines.append(routine)
        persistRoutines()
    }

    func delete(routineId: String) {
        routines.removeAll { $0.id == routineId }
        persistRoutines()
    }

    func rename(routineId: String, to name: String) {
        guard let index = routines.firstIndex(where: { $0.id == routineId }) else { return }
        routines[index].name = name
        persistRoutines()
    }

    func markRoutineRun(_ routineId: String) {
        guard let index = routines.firstIndex(where: { $0.id == routineId }) else { return }
        routines[index].runCount += 1
        persistRoutines()
    }

    func setEnabled(_ enabled: Bool, routineId: String) {
        guard let index = routines.firstIndex(where: { $0.id == routineId }) else { return }
        routines[index].isEnabled = enabled
        persistRoutines()
    }

    func setSchedule(hour: Int?, routineId: String) {
        guard let index = routines.firstIndex(where: { $0.id == routineId }) else { return }
        routines[index].scheduleHour = hour
        persistRoutines()
    }

    func markScheduledFire(_ routineId: String) {
        guard let index = routines.firstIndex(where: { $0.id == routineId }) else { return }
        routines[index].lastScheduledFire = Date()
        persistRoutines()
    }

    /// Picks the routine whose trigger best matches a fresh request.
    ///
    /// Deliberately a keyword overlap score rather than an embedding lookup:
    /// a bot owns a handful of routines, the triggers are one sentence each, and
    /// a wrong match here is worse than no match — it would silently replay the
    /// wrong workflow. Overlap is easy to reason about and easy for the user to
    /// fix by renaming a trigger.
    func routine(matching request: String, for botId: String) -> StreamBotRoutine? {
        let words = Self.keywords(in: request)
        guard words.count >= 2 else { return nil }
        var best: (routine: StreamBotRoutine, score: Int)?
        for routine in routines(for: botId) where routine.isEnabled {
            let triggerWords = Self.keywords(in: routine.trigger + " " + routine.name)
            let score = words.intersection(triggerWords).count
            if score >= 2, score > (best?.score ?? 1) {
                best = (routine, score)
            }
        }
        return best?.routine
    }

    private static func keywords(in text: String) -> Set<String> {
        let stop: Set<String> = [
            "the", "and", "for", "with", "that", "this", "from", "into", "your",
            "you", "our", "are", "all", "any", "can", "please", "then", "them",
            "when", "what", "who", "how", "get", "got", "has", "have", "was",
            "were", "will", "would", "should", "could", "about", "over", "each"
        ]
        return Set(
            text.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 2 && !stop.contains($0) }
        )
    }

    // MARK: Memory

    func memories(for botId: String) -> [StreamBotMemory] {
        memories.filter { $0.botId == botId }.sorted { $0.createdAt > $1.createdAt }
    }

    /// Adds a memory unless the bot already remembers something near-identical.
    /// Without the duplicate guard the same "keep it short" preference gets
    /// re-learned after every run and crowds out everything else.
    func remember(_ memory: StreamBotMemory) {
        let incoming = Self.keywords(in: memory.text)
        let alreadyKnown = memories.contains { existing in
            existing.botId == memory.botId
                && !incoming.isEmpty
                && Self.keywords(in: existing.text).intersection(incoming).count
                    >= max(2, incoming.count * 2 / 3)
        }
        guard !alreadyKnown else { return }
        memories.append(memory)
        // Keep the most recent window per bot; instructions have a budget.
        let forBot = memories.filter { $0.botId == memory.botId }
            .sorted { $0.createdAt > $1.createdAt }
        if forBot.count > Self.memoryLimit {
            let drop = Set(forBot.dropFirst(Self.memoryLimit).map(\.id))
            memories.removeAll { drop.contains($0.id) }
        }
        persistMemories()
    }

    func forget(memoryId: String) {
        memories.removeAll { $0.id == memoryId }
        persistMemories()
    }

    func forgetAll(for botId: String) {
        memories.removeAll { $0.botId == botId }
        persistMemories()
    }

    private static let memoryLimit = 24

    // MARK: Instructions

    func instructions(for botId: String) -> String {
        instructions[botId]?.custom ?? ""
    }

    func setInstructions(_ text: String, for botId: String) {
        instructions[botId] = StreamBotInstructions(botId: botId, custom: text)
        Self.save(Array(instructions.values), to: .instructions)
    }

    // MARK: Locally created bots

    func noteCreatedBot(_ id: String) {
        locallyCreatedBotIds.insert(id)
        Self.save(Array(locallyCreatedBotIds), to: .createdBots)
    }

    // MARK: Persistence

    private func persistRoutines() { Self.save(routines, to: .routines) }
    private func persistMemories() { Self.save(memories, to: .memories) }

    private enum File: String {
        case routines, memories, instructions, createdBots

        var url: URL {
            StreamBotStore.directory.appendingPathComponent("\(rawValue).json")
        }
    }

    private static var directory: URL {
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("owngrokbot", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func load<T: Decodable>(_ type: T.Type, from file: File) -> T? {
        guard let data = try? Data(contentsOf: file.url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }

    private static func save<T: Encodable>(_ value: T, to file: File) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: file.url, options: .atomic)
    }
}
#endif
