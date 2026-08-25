#if os(iOS)
// StreamBotScheduler.swift
// Grok Bot's "routines on a schedule". StreamBot's bots think on this phone,
// so a scheduled routine fires the next time the app is opened after its hour
// — not at 7:00 while the device is asleep. That limit is the product, not a
// bug: there is no cloud computer to keep working after you close the lid.

import Foundation

@MainActor
enum StreamBotScheduler {
    /// Walks every enabled, scheduled routine and starts the ones whose hour
    /// has arrived since they last ran.
    static func fireDueRoutines() {
        let store = StreamBotStore.shared
        let roster = StreamBotRoster.shared
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now.converting(to: StreamBotPreferences.shared.timeZone))

        for routine in store.routines where routine.isEnabled {
            guard let scheduledHour = routine.scheduleHour else { continue }
            guard hour >= scheduledHour else { continue }
            if let last = routine.lastScheduledFire,
               calendar.isDate(last, inSameDayAs: now) {
                continue
            }
            guard let bot = roster.bot(id: routine.botId) else { continue }
            guard !StreamBotEngine.shared.isBusy(in: bot.threadChannelId) else { continue }

            store.markScheduledFire(routine.id)
            StreamBotNotifications.notifyScheduled(bot: bot, routine: routine.name)
            StreamBotEngine.shared.start(
                request: "Run the scheduled routine “\(routine.name)”. Trigger: \(routine.trigger). Follow the taught steps.",
                userMessageId: nil,
                bot: bot,
                in: bot.threadChannelId
            )
        }
    }
}

private extension Date {
    func converting(to timeZone: TimeZone) -> Date {
        let offset = TimeInterval(timeZone.secondsFromGMT(for: self) - TimeZone.current.secondsFromGMT(for: self))
        return addingTimeInterval(offset)
    }
}
#endif
