#if os(iOS)
// StreamBotSettingsView.swift
// The Settings surface Grok Bot 1.3 added: haptics, notifications, a timezone
// for scheduled routines, and a reconnect for the on-device runtime.

import FoundationModels
import SwiftUI

struct StreamBotSettingsView: View {
    private let preferences = StreamBotPreferences.shared
    private let roster = StreamBotRoster.shared
    private let engine = StreamBotEngine.shared

    @State private var isReconnecting = false
    @State private var reconnectNote: String?

    var body: some View {
        NavigationStack {
            ZStack {
                StreamBotBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        StreamBotEditorialHeader(
                            eyebrow: "This device",
                            title: "Settings",
                            detail: "Haptics, pings, and the on-device runtime. These stay on this phone."
                        )

                        feel
                        alerts
                        runtime
                        schedule
                        about
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var feel: some View {
        StreamBotCard {
            VStack(alignment: .leading, spacing: 12) {
                StreamBotSectionLabel(text: "Feel", symbol: "hand.tap")
                Toggle(isOn: Binding(
                    get: { preferences.hapticsEnabled },
                    set: { preferences.hapticsEnabled = $0; if $0 { StreamBotHaptics.success() } }
                )) {
                    settingLabel(
                        "Haptics",
                        detail: "A tap when a bot starts, needs you, or finishes.",
                        symbol: "waveform"
                    )
                }
                .tint(.streamBot)
            }
        }
    }

    private var alerts: some View {
        StreamBotCard {
            VStack(alignment: .leading, spacing: 12) {
                StreamBotSectionLabel(text: "Alerts", symbol: "bell")
                Toggle(isOn: Binding(
                    get: { preferences.notificationsEnabled },
                    set: { newValue in
                        if newValue {
                            Task { _ = await StreamBotNotifications.requestAuthorization() }
                        } else {
                            preferences.notificationsEnabled = false
                        }
                    }
                )) {
                    settingLabel(
                        "Notifications",
                        detail: "When a bot finishes, fails, or parks a draft for approval.",
                        symbol: "bell.badge"
                    )
                }
                .tint(.streamBot)

                if preferences.notificationsEnabled, !roster.bots.isEmpty {
                    Divider().opacity(0.5)
                    Text("Per teammate")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.streamBotSecondary)
                    ForEach(roster.bots) { bot in
                        Toggle(isOn: Binding(
                            get: { preferences.notificationsEnabled(for: bot.id) },
                            set: { preferences.setNotificationsEnabled($0, for: bot.id) }
                        )) {
                            HStack(spacing: 10) {
                                StreamBotAvatar(
                                    symbolName: bot.symbolName,
                                    accent: bot.color,
                                    size: 28
                                )
                                Text(bot.shortName)
                                    .font(.subheadline)
                            }
                        }
                        .tint(bot.color)
                    }
                }
            }
        }
    }

    private var runtime: some View {
        StreamBotCard {
            VStack(alignment: .leading, spacing: 12) {
                StreamBotSectionLabel(text: "Runtime", symbol: "desktopcomputer")
                Text("Grok Bot reconnects a cloud computer. StreamBot reloads the on-device model and drops abandoned runs — the honest equivalent, because the work lives here.")
                    .font(.caption)
                    .foregroundStyle(.streamBotSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Image(systemName: AIModelPreferences.shared.textModel.symbolName)
                        .font(.subheadline.weight(.semibold))
                        .streamBotAccentText(.streamBot)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(AIModelPreferences.shared.textModel.displayName)
                            .font(.subheadline.weight(.semibold))
                        Text(runtimeStatus)
                            .font(.caption)
                            .foregroundStyle(.streamBotSecondary)
                    }
                    Spacer(minLength: 0)
                }

                StreamBotActionButton(
                    title: isReconnecting ? "Reconnecting" : "Reconnect runtime",
                    symbolName: "arrow.clockwise",
                    size: .small,
                    isBusy: isReconnecting
                ) {
                    reconnect()
                }

                if let reconnectNote {
                    Text(reconnectNote)
                        .font(.caption)
                        .foregroundStyle(.streamBotSecondary)
                }
            }
        }
    }

    private var runtimeStatus: String {
        let working = engine.workingBots.count
        let waiting = engine.waitingBots.count
        if working > 0 { return "\(working) working" }
        if waiting > 0 { return "\(waiting) waiting for you" }
        return "Idle — ready to think"
    }

    private var schedule: some View {
        StreamBotCard {
            VStack(alignment: .leading, spacing: 12) {
                StreamBotSectionLabel(text: "Schedules", symbol: "clock")
                Text("Routines fire the next time you open the app after their hour. They cannot run while the phone is asleep.")
                    .font(.caption)
                    .foregroundStyle(.streamBotSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Picker("Time zone", selection: Binding(
                    get: { preferences.timeZoneIdentifier },
                    set: { preferences.timeZoneIdentifier = $0 }
                )) {
                    Text("This iPhone").tag("")
                    Text("UTC").tag("UTC")
                    Text("US Eastern").tag("America/New_York")
                    Text("US Pacific").tag("America/Los_Angeles")
                    Text("London").tag("Europe/London")
                }
                .pickerStyle(.menu)
                .tint(.primary)
            }
        }
    }

    private var about: some View {
        StreamBotCard {
            VStack(alignment: .leading, spacing: 8) {
                StreamBotSectionLabel(text: "On device", symbol: "lock.iphone")
                Text("Reasoning, drafts, dictation, plugins, and memory never leave this phone. Only the chat itself — messages, channels, presence — goes through Stream.")
                    .font(.caption)
                    .foregroundStyle(.streamBotSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func settingLabel(_ title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.subheadline)
                .streamBotAccentText(.streamBot)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.streamBotSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func reconnect() {
        isReconnecting = true
        reconnectNote = nil
        StreamBotEngine.shared.reconnectRuntime()
        CoreAITextSessionProvider.shared.unload()
        StreamBotHaptics.success()
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            isReconnecting = false
            reconnectNote = "Runtime reloaded. The next message loads a fresh session."
        }
    }
}
#endif
