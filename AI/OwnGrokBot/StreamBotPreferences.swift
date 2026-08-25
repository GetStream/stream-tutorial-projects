#if os(iOS)
// StreamBotPreferences.swift
// The knobs Grok Bot 1.3 put in Settings, kept on this device: haptics,
// notifications, and the timezone scheduled routines fire in.
//
// Nothing here leaves the phone. The real Grok Bot syncs settings across a
// cloud computer; StreamBot's analog is UserDefaults, which is the honest
// place for preferences that only this device can act on.

import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class StreamBotPreferences {
    static let shared = StreamBotPreferences()

    var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: Key.haptics) }
    }

    var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: Key.notifications) }
    }

    /// IANA identifier. Empty means "whatever this iPhone is on".
    var timeZoneIdentifier: String {
        didSet { UserDefaults.standard.set(timeZoneIdentifier, forKey: Key.timeZone) }
    }

    /// Bots the user has asked not to ping. Default is on for everyone.
    var mutedNotificationBotIds: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(mutedNotificationBotIds), forKey: Key.mutedBots)
        }
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    var timeZoneLabel: String {
        timeZoneIdentifier.isEmpty
            ? "This iPhone (\(TimeZone.current.identifier))"
            : timeZoneIdentifier.replacingOccurrences(of: "_", with: " ")
    }

    private init() {
        let defaults = UserDefaults.standard
        hapticsEnabled = defaults.object(forKey: Key.haptics) as? Bool ?? true
        notificationsEnabled = defaults.bool(forKey: Key.notifications)
        timeZoneIdentifier = defaults.string(forKey: Key.timeZone) ?? ""
        mutedNotificationBotIds = Set(defaults.stringArray(forKey: Key.mutedBots) ?? [])
    }

    func notificationsEnabled(for botId: String) -> Bool {
        notificationsEnabled && !mutedNotificationBotIds.contains(botId)
    }

    func setNotificationsEnabled(_ enabled: Bool, for botId: String) {
        if enabled {
            mutedNotificationBotIds.remove(botId)
        } else {
            mutedNotificationBotIds.insert(botId)
        }
    }

    private enum Key {
        static let haptics = "streambot.haptics"
        static let notifications = "streambot.notifications"
        static let timeZone = "streambot.timezone"
        static let mutedBots = "streambot.mutedBots"
    }
}

// MARK: - Haptics

/// Tactile confirmation for the moments that change a bot's work. Off is a
/// setting, not a missing implementation — Grok Bot 1.3 added the same switch.
enum StreamBotHaptics {
    static func light() {
        guard StreamBotPreferences.shared.hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        guard StreamBotPreferences.shared.hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        guard StreamBotPreferences.shared.hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        guard StreamBotPreferences.shared.hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func selection() {
        guard StreamBotPreferences.shared.hapticsEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func phaseChanged(_ phase: StreamBotEngine.Phase) {
        switch phase {
        case .awaitingApproval: warning()
        case .failed: warning()
        case .planning: light()
        default: break
        }
    }
}
#endif
