#if os(iOS)
// StreamBotNotifications.swift
// Local pings when a bot finishes or needs a yes. Grok Bot's iOS 1.3 notes
// "improved notifications"; here they are on-device because the work is too.
//
// Asked for at the Settings switch, not on first launch. A teammate that wants
// attention is not the same as an app that wants permission.

import Foundation
import UserNotifications

@MainActor
enum StreamBotNotifications {
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        StreamBotPreferences.shared.notificationsEnabled = granted
        return granted
    }

    static func notifyApproval(bot: StreamBotTeammate, title: String) {
        post(
            bot: bot,
            identifier: "approval.\(bot.id)",
            title: "\(bot.shortName) needs you",
            body: title.isEmpty ? "A draft is waiting for your approval." : title
        )
    }

    static func notifyFinished(bot: StreamBotTeammate, title: String) {
        post(
            bot: bot,
            identifier: "done.\(bot.id).\(UUID().uuidString)",
            title: "\(bot.shortName) finished",
            body: title.isEmpty ? "The run is done." : title
        )
    }

    static func notifyFailed(bot: StreamBotTeammate, message: String) {
        post(
            bot: bot,
            identifier: "fail.\(bot.id).\(UUID().uuidString)",
            title: "\(bot.shortName) couldn't finish",
            body: message
        )
    }

    static func notifyScheduled(bot: StreamBotTeammate, routine: String) {
        post(
            bot: bot,
            identifier: "sched.\(bot.id).\(routine)",
            title: "\(bot.shortName) is running “\(routine)”",
            body: "A scheduled routine just started."
        )
    }

    private static func post(
        bot: StreamBotTeammate,
        identifier: String,
        title: String,
        body: String
    ) {
        guard StreamBotPreferences.shared.notificationsEnabled(for: bot.id) else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
#endif
