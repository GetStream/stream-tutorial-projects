#if os(iOS)
// StreamBotShareIntake.swift
// Grok Bot 1.3 added sharing from other apps. StreamBot takes the same
// inbound: a URL scheme, a text file dropped on the app, or whatever is on
// the pasteboard. The user then picks which teammate gets it.
//
// There is no share-extension target in this demo, so Safari's Share sheet
// cannot list StreamBot by itself. `streambot://handoff?text=` and "Open in"
// for text files are the routes that actually land here.

import Foundation
import Observation
import StreamChat
import SwiftUI
import UIKit

@MainActor
@Observable
final class StreamBotShareIntake {
    static let shared = StreamBotShareIntake()

    struct Payload: Identifiable, Equatable {
        let id = UUID()
        var text: String
        var source: String
    }

    var pending: Payload?

    private init() {}

    func handle(url: URL) {
        if url.scheme == "streambot" {
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems ?? []
            let text = items.first(where: { $0.name == "text" })?.value?
                .removingPercentEncoding
                ?? items.first(where: { $0.name == "body" })?.value
            guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            pending = Payload(text: text, source: "Shared link")
            return
        }

        guard url.isFileURL else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        if let text = try? String(contentsOf: url, encoding: .utf8),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pending = Payload(text: text, source: url.lastPathComponent)
        }
    }

    func handlePasteboard() {
        guard let text = UIPasteboard.general.string?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return }
        pending = Payload(text: String(text.prefix(8_000)), source: "Clipboard")
    }

    func clear() { pending = nil }
}

/// Pick a teammate for something that arrived from another app.
struct StreamBotShareHandoffSheet: View {
    let payload: StreamBotShareIntake.Payload

    @Environment(\.dismiss) private var dismiss
    private let roster = StreamBotRoster.shared
    @State private var selected: StreamBotTeammate?

    var body: some View {
        NavigationStack {
            ZStack {
                StreamBotBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        StreamBotCard {
                            VStack(alignment: .leading, spacing: 8) {
                                StreamBotSectionLabel(text: payload.source, symbol: "square.and.arrow.down")
                                Text(payload.text)
                                    .font(.subheadline)
                                    .lineLimit(8)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        StreamBotCard {
                            VStack(alignment: .leading, spacing: 10) {
                                StreamBotSectionLabel(text: "Hand off to", symbol: "person.2")
                                ForEach(roster.bots) { bot in
                                    Button {
                                        selected = bot
                                        StreamBotHaptics.selection()
                                    } label: {
                                        HStack(spacing: 12) {
                                            StreamBotAvatar(
                                                symbolName: bot.symbolName,
                                                accent: bot.color,
                                                size: 36
                                            )
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(bot.shortName)
                                                    .font(.subheadline.weight(.semibold))
                                                Text(bot.roleName)
                                                    .font(.caption)
                                                    .foregroundStyle(.streamBotSecondary)
                                            }
                                            Spacer(minLength: 0)
                                            if selected?.id == bot.id {
                                                Image(systemName: "checkmark")
                                                    .font(.caption.weight(.bold))
                                                    .streamBotAccentText(bot.color)
                                            }
                                        }
                                        .contentShape(.rect)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("From another app")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        StreamBotShareIntake.shared.clear()
                        dismiss()
                    }
                    .tint(.primary)
                    .foregroundStyle(.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    StreamBotActionButton(
                        title: "Send",
                        isProminent: true,
                        tint: selected?.color,
                        size: .small
                    ) {
                        handoff()
                    }
                    .disabled(selected == nil)
                }
            }
        }
    }

    private func handoff() {
        guard let bot = selected else { return }
        StreamBotEngine.shared.start(
            request: payload.text,
            userMessageId: nil,
            bot: bot,
            in: bot.threadChannelId
        )
        StreamBotHaptics.success()
        StreamBotShareIntake.shared.clear()
        dismiss()
    }
}
#endif
