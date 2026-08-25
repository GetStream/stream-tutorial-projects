#if os(iOS)
// StreamBotPluginStore.swift
// What is installed, which teammate it is switched on for, and whether the
// system has actually granted the access a connector needs.
//
// Two levels, exactly as Grok Bot's Settings → Plugins works: a plugin is added
// once for the account, and then enabled per Bot. That split matters here — the
// Calendar plugin being installed says the user is willing to let the app read
// their calendar; it being enabled on the Bug Reproduction bot would just mean
// Pike wastes a tool call on every run.
//
// Installing asks for the system permission up front. A run that stops in the
// middle to raise a permission sheet has already lost the user's attention, and
// a bot that silently plans around access it never got is worse than one that
// says it cannot.

import Contacts
import EventKit
import Foundation
import Observation

@MainActor
@Observable
final class StreamBotPluginStore {
    static let shared = StreamBotPluginStore()

    /// The result of an Add, so the marketplace can say what happened rather than
    /// leaving a row looking like it did nothing.
    enum InstallOutcome: Equatable {
        case installed
        /// Installed, but the system refused the access it needs. The plugin's
        /// skills still work; its connector will report that it has no access.
        case installedWithoutPermission(String)
        case failed(String)
    }

    private(set) var installedIds: Set<String> = []
    /// Plugin id → bots the user switched it on for, against its lane default.
    private(set) var switchedOn: [String: Set<String>] = [:]
    /// Plugin id → bots the user switched it off for.
    ///
    /// Two sets rather than one list of enabled bots, because a plugin's default
    /// is by lane: recording only the enabled ids would freeze the roster at
    /// install time, and a teammate hired next week would come up with none of the
    /// plugins its lane is supposed to have.
    private(set) var switchedOff: [String: Set<String>] = [:]

    private init() {
        let state = Self.load()
        installedIds = Set(state?.installed ?? [])
        switchedOn = (state?.on ?? [:]).mapValues(Set.init)
        switchedOff = (state?.off ?? [:]).mapValues(Set.init)

        // First launch gets the two connectors that need no permission and are
        // useful to every teammate, so the feature is live before the user has
        // visited the marketplace — and a model asked to plan "by Thursday" knows
        // what day it is. `hasSeeded` is persisted, so removing them sticks.
        if state?.hasSeeded != true {
            installedIds.formUnion([StreamBotPluginCatalog.clock.id, StreamBotPluginCatalog.threads.id])
            persist()
        }
    }

    // MARK: Reading

    func isInstalled(_ plugin: StreamBotPlugin) -> Bool {
        installedIds.contains(plugin.id)
    }

    var installed: [StreamBotPlugin] {
        StreamBotPluginCatalog.all.filter { installedIds.contains($0.id) }
    }

    func isEnabled(_ plugin: StreamBotPlugin, for botId: String) -> Bool {
        guard installedIds.contains(plugin.id) else { return false }
        if switchedOn[plugin.id]?.contains(botId) == true { return true }
        if switchedOff[plugin.id]?.contains(botId) == true { return false }
        guard let lane = StreamBotRoster.shared.byId[botId]?.lane else { return false }
        return plugin.suggestedLanes.contains(lane)
    }

    /// Everything switched on for one teammate, which is what the engine builds a
    /// run out of.
    func plugins(for botId: String) -> [StreamBotPlugin] {
        installed.filter { isEnabled($0, for: botId) }
    }

    func connectors(for botId: String) -> [StreamBotConnector] {
        plugins(for: botId).compactMap(\.connector)
    }

    func skills(for botId: String) -> [StreamBotSkill] {
        plugins(for: botId).flatMap(\.skills)
    }

    /// How many teammates have this switched on — the number the Yours tab shows.
    func enabledCount(for plugin: StreamBotPlugin) -> Int {
        StreamBotRoster.shared.bots.count { isEnabled(plugin, for: $0.id) }
    }

    // MARK: Installing

    /// Adds a plugin, asking for whatever access it needs first.
    ///
    /// Which teammates it lands on is not decided here — `suggestedLanes` decides
    /// it, and keeps deciding it for bots hired later. Adding Calendar and then
    /// being asked which of nine bots should have it is a worse experience than
    /// adding it and finding it already on for the two that plan the user's week.
    func install(_ plugin: StreamBotPlugin) async -> InstallOutcome {
        var outcome = InstallOutcome.installed
        if case .failure(let reason) = await Self.requestPermission(plugin.permission) {
            outcome = .installedWithoutPermission(reason)
        }
        installedIds.insert(plugin.id)
        persist()
        return outcome
    }

    func uninstall(_ plugin: StreamBotPlugin) {
        installedIds.remove(plugin.id)
        switchedOn[plugin.id] = nil
        switchedOff[plugin.id] = nil
        persist()
    }

    func setEnabled(_ isOn: Bool, plugin: StreamBotPlugin, botId: String) {
        var on = switchedOn[plugin.id] ?? []
        var off = switchedOff[plugin.id] ?? []
        if isOn {
            on.insert(botId)
            off.remove(botId)
        } else {
            off.insert(botId)
            on.remove(botId)
        }
        switchedOn[plugin.id] = on
        switchedOff[plugin.id] = off
        persist()
    }

    // MARK: Permissions

    /// Whether the system currently allows what this plugin needs. Read on every
    /// appearance rather than cached: the user can revoke it in Settings while the
    /// app is backgrounded, and a plugin page claiming access it lost is a lie.
    static func isPermitted(_ permission: StreamBotPluginPermission) -> Bool {
        switch permission {
        case .none:
            true
        case .calendar:
            StreamBotEventKit.shared.hasEventAccess
        case .reminders:
            StreamBotEventKit.shared.hasReminderAccess
        case .contacts:
            hasContactsAccess
        }
    }

    /// Limited access (iOS 18+) still lets a lookup succeed for the contacts
    /// the user picked, so it counts as permitted.
    private static var hasContactsAccess: Bool {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited: true
        default: false
        }
    }

    private enum PermissionResult {
        case granted
        case failure(String)
    }

    private static func requestPermission(_ permission: StreamBotPluginPermission) async -> PermissionResult {
        switch permission {
        case .none:
            return .granted
        case .calendar:
            return await StreamBotEventKit.shared.requestEventAccess()
                ? .granted
                : .failure("Calendar access was declined. Turn it on in Settings → StreamBot to let bots read your events.")
        case .reminders:
            return await StreamBotEventKit.shared.requestReminderAccess()
                ? .granted
                : .failure("Reminders access was declined. Turn it on in Settings → StreamBot.")
        case .contacts:
            do {
                return try await CNContactStore().requestAccess(for: .contacts)
                    ? .granted
                    : .failure("Contacts access was declined. Turn it on in Settings → StreamBot.")
            } catch {
                return .failure(error.localizedDescription)
            }
        }
    }

    // MARK: Persistence

    private struct State: Codable {
        var installed: [String]
        var on: [String: [String]]
        var off: [String: [String]]
        var hasSeeded: Bool
    }

    private func persist() {
        Self.save(
            State(
                installed: Array(installedIds),
                on: switchedOn.mapValues(Array.init),
                off: switchedOff.mapValues(Array.init),
                hasSeeded: true
            )
        )
    }

    private static var url: URL {
        let directory = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("owngrokbot", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("plugins.json")
    }

    private static func load() -> State? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(State.self, from: data)
    }

    private static func save(_ state: State) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
#endif
