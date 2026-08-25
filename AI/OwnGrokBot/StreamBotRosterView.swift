#if os(iOS)
// StreamBotRosterView.swift
// The team. Every teammate, what they are working on, and how to hire another.
//
// This is the screen that answers "what have I got working for me?", which is a
// different question from the chat list's "what did I say last?". Hence the
// separate tab: the roster is sorted by lane and never reorders when a message
// arrives, so a bot is always in the same place on the grid.

import StreamChat
import SwiftUI

struct StreamBotRosterView: View {
    private let roster = StreamBotRoster.shared
    private let store = StreamBotStore.shared
    private let engine = StreamBotEngine.shared

    @State private var isHiring = false
    @State private var isBrowsingPlugins = false
    @State private var selected: StreamBotTeammate?

    var body: some View {
        NavigationStack {
            ZStack {
                StreamBotBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        grid
                        if let error = roster.loadError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.streamBotSecondary)
                                .padding(.horizontal, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    StreamBotRoundButton(
                        symbolName: "square.and.arrow.down",
                        accessibilityLabel: "Hand off from clipboard",
                        size: .small
                    ) {
                        StreamBotShareIntake.shared.handlePasteboard()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    StreamBotRoundButton(
                        symbolName: "puzzlepiece.extension",
                        accessibilityLabel: "Plugins",
                        size: .small
                    ) {
                        isBrowsingPlugins = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    StreamBotRoundButton(
                        symbolName: "plus",
                        accessibilityLabel: "Hire a bot",
                        isProminent: true,
                        size: .small
                    ) {
                        isHiring = true
                    }
                }
            }
            .sheet(isPresented: $isHiring) {
                StreamBotHireView()
            }
            .sheet(isPresented: $isBrowsingPlugins) {
                StreamBotPluginsView()
            }
            .sheet(item: $selected) { bot in
                StreamBotDetailView(bot: bot, cid: bot.threadChannelId)
            }
            .task { roster.load() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            StreamBotEditorialHeader(
                eyebrow: "Your team",
                title: "Teammates",
                detail: "Hire a specialist, hand off work in a thread, and stay in the loop only when something needs your yes."
            )
            HStack(spacing: 8) {
                StreamBotStatChip(
                    value: engine.workingBots.count,
                    label: "working",
                    tint: .green,
                    symbolName: "bolt.fill"
                )
                StreamBotStatChip(
                    value: engine.waitingBots.count,
                    label: "need you",
                    tint: .orange,
                    symbolName: "hand.raised.fill"
                )
                Spacer(minLength: 0)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 164), spacing: 14)],
            spacing: 14
        ) {
            ForEach(roster.bots) { bot in
                Button {
                    StreamBotHaptics.light()
                    selected = bot
                } label: {
                    StreamBotTile(bot: bot, routineCount: store.routines(for: bot.id).count)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Tile

struct StreamBotTile: View {
    let bot: StreamBotTeammate
    let routineCount: Int

    @Environment(\.colorScheme) private var colorScheme

    private var phase: StreamBotEngine.Phase {
        StreamBotEngine.shared.phase(in: bot.threadChannelId)
    }

    var body: some View {
        StreamBotCard(tint: bot.color, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    StreamBotAvatar(
                        symbolName: bot.symbolName,
                        accent: bot.color,
                        size: 44,
                        isWorking: phase.isBusy
                    )
                    Spacer()
                    StreamBotStatusDot(activity: activity)
                    Image(systemName: bot.approval.symbolName)
                        .font(.caption)
                        .foregroundStyle(.streamBotSecondary)
                        .accessibilityLabel(bot.approval.title)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(bot.shortName)
                        .font(.headline)
                    Text(bot.roleName)
                        .font(.caption)
                        .foregroundStyle(.streamBotSecondary)
                        .lineLimit(1)
                }
                Text(phase.shortLabel ?? bot.tagline)
                    .font(.caption)
                    .foregroundStyle(phase.isBusy || phase == .awaitingApproval
                        ? bot.color.streamBotOnGlass(in: colorScheme)
                        : .streamBotSecondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 5) {
                    StreamBotPill(text: bot.lane.title, tint: bot.color, isProminent: true)
                    if routineCount > 0 {
                        StreamBotPill(text: "\(routineCount)", symbolName: "graduationcap.fill")
                    }
                }
            }
        }
    }

    private var activity: StreamBotStatusDot.Activity {
        switch phase {
        case .idle: .idle
        case .planning, .working, .replying: .working
        case .awaitingApproval: .waiting
        case .failed: .failed
        }
    }
}

// MARK: - Hiring

/// Creating a bot is picking a preset and naming it.
///
/// Not a blank form: a bot is only useful if its lane, policy and starting
/// surfaces are coherent, and a free-text "describe your bot" field produces
/// neither. The preset carries all of that, and the one thing worth the user's
/// attention — what to call it — is the one thing they type.
struct StreamBotHireView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var preset: StreamBotPreset = StreamBotPreset.all[0]
    @State private var name = ""
    @State private var isCreating = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                StreamBotBackdrop(tint: preset.accent.color)
                ScrollView {
                    VStack(spacing: 14) {
                        StreamBotCard(tint: preset.accent.color) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 12) {
                                    StreamBotAvatar(
                                        symbolName: preset.symbolName,
                                        accent: preset.accent.color,
                                        size: 48
                                    )
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(name.isEmpty ? preset.name : name)
                                            .font(.headline)
                                        Text(preset.role)
                                            .font(.caption)
                                            .foregroundStyle(.streamBotSecondary)
                                    }
                                }
                                Text(preset.tagline)
                                    .font(.footnote)
                                    .foregroundStyle(.streamBotSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                TextField(
                                    "",
                                    text: $name,
                                    prompt: Text(preset.name).foregroundStyle(Color.streamBotTertiary)
                                )
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .padding(10)
                                .glassEffect(.regular, in: .rect(cornerRadius: 14))
                            }
                        }

                        StreamBotCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("What it does")
                                    .font(.subheadline.weight(.semibold))
                                ForEach(StreamBotPreset.all) { option in
                                    Button {
                                        StreamBotHaptics.selection()
                                        preset = option
                                    } label: {
                                        HStack(spacing: 10) {
                                            StreamBotAvatar(
                                                symbolName: option.symbolName,
                                                accent: option.accent.color,
                                                size: 30
                                            )
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(option.role)
                                                    .font(.subheadline)
                                                Text(option.approval.title)
                                                    .font(.caption)
                                                    .foregroundStyle(.streamBotSecondary)
                                            }
                                            Spacer()
                                            if option.id == preset.id {
                                                Image(systemName: "checkmark")
                                                    .font(.caption.weight(.bold))
                                                    .streamBotAccentText(option.accent.color)
                                            }
                                        }
                                        .contentShape(.rect)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        if let error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .multilineTextAlignment(.center)
                        }

                        // The honest caveat, stated where the decision is made:
                        // authoring messages as a bot needs a token minted for
                        // that user, and this app ships no backend to mint one.
                        Text("Teammates you create here get a thread of their own. Only the seeded bots have access tokens in this build, so a new hire cannot post until one is minted for it.")
                            .font(.caption)
                            .foregroundStyle(.streamBotSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Hire a bot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .tint(.primary)
                        .foregroundStyle(.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    StreamBotActionButton(
                        title: "Hire",
                        isProminent: true,
                        tint: preset.accent.color,
                        size: .small,
                        isBusy: isCreating
                    ) {
                        create()
                    }
                }
            }
        }
    }

    private func create() {
        isCreating = true
        error = nil

        // A stable, readable id derived from the preset, suffixed so two
        // "Inbox Manager" hires do not collide.
        let suffix = String(UUID().uuidString.prefix(6)).lowercased()
        var bot = preset.makeBot(userId: "grok-\(preset.id)-\(suffix)")
        if !name.trimmingCharacters(in: .whitespaces).isEmpty {
            bot.name = "\(name.trimmingCharacters(in: .whitespaces)) — \(preset.role)"
        }

        do {
            _ = try StreamBotChatService.shared.createThread(for: bot)
            StreamBotStore.shared.noteCreatedBot(bot.id)
            StreamBotRoster.shared.insert(bot)
            StreamBotHaptics.success()
            dismiss()
        } catch {
            self.error = error.localizedDescription
            isCreating = false
        }
    }
}
#endif
