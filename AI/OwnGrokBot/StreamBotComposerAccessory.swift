#if os(iOS)
// StreamBotComposerAccessory.swift
// The strip above the composer. It shows one of three things, never two, so the
// area above the keyboard has a single job at any moment:
//
//   * Dictating — waveform, live transcript, and a way out.
//   * A run in flight — what the bot is doing, and Stop.
//   * Otherwise — starter prompts for this bot's lane, and the mic.
//
// The dictation UI deliberately renders finalized and volatile speech
// differently. SpeechTranscriber revises its guesses as you keep talking, and
// showing that happening is what makes dictation feel accurate instead of
// unpredictable — you can see the model settle on a word rather than watching
// text mysteriously rewrite itself.

import StreamChat
import StreamChatSwiftUI
import SwiftUI

struct StreamBotComposerAccessory: View {
    let cid: ChannelId
    /// Nil in a room, where the message has not been addressed to anyone yet.
    let bot: StreamBotTeammate?
    @ObservedObject var composerViewModel: MessageComposerViewModel

    @State private var dictation = StreamBotVoiceDictation()
    /// The draft as it was before dictation started, so speech is appended to
    /// what the user already typed rather than replacing it.
    @State private var draftBeforeDictation = ""
    /// After Stop, the user reviews the words and chooses Send or Insert.
    /// Recording and sending are separate on purpose — Grok Bot 1.3's dictation
    /// change, kept here so a misheard sentence never fires a run.
    @State private var isReviewing = false

    private var phase: StreamBotEngine.Phase { StreamBotEngine.shared.phase(in: cid) }

    var body: some View {
        VStack(spacing: 8) {
            if dictation.phase.isActive {
                recordingPanel
            } else if isReviewing {
                reviewPanel
            } else if phase.isBusy {
                runStrip
            } else {
                idleStrip
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .animation(.smooth(duration: 0.3), value: dictation.phase)
        .animation(.smooth(duration: 0.3), value: isReviewing)
        .animation(.smooth(duration: 0.3), value: phase)
        .onChange(of: dictation.transcript) { _, transcript in
            // Live-write into the real composer so the user edits and sends from
            // the same field they always do. The panel is a monitor, not a
            // second text box to copy out of.
            guard dictation.isListening else { return }
            composerViewModel.text = draftBeforeDictation + transcript
        }
    }

    // MARK: Recording

    private var recordingPanel: some View {
        StreamBotCard(tint: bot?.color, cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    if case .preparing(let step) = dictation.phase {
                        ProgressView().controlSize(.small)
                        Text(step)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.streamBotSecondary)
                    } else {
                        StreamBotPill(
                            text: "Recording",
                            symbolName: "mic.fill",
                            tint: .red,
                            isProminent: true
                        )
                        StreamBotWaveform(
                            level: dictation.level,
                            tint: bot?.color ?? .streamBot,
                            maxHeight: 26
                        )
                    }
                    Spacer(minLength: 0)
                }

                if dictation.hasTranscript {
                    (
                        Text(dictation.finalizedText)
                            .foregroundStyle(.primary)
                            + Text(dictation.volatileText)
                            .foregroundStyle(.streamBotSecondary)
                    )
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(4)
                    .animation(nil, value: dictation.volatileText)
                } else if dictation.isListening {
                    Text("Listening — say what you need done.")
                        .font(.subheadline)
                        .foregroundStyle(.streamBotSecondary)
                }

                HStack(spacing: 8) {
                    StreamBotActionButton(
                        title: "Stop",
                        symbolName: "stop.fill",
                        isProminent: true,
                        tint: .red,
                        size: .small
                    ) {
                        Task { await stopRecording() }
                    }
                    StreamBotActionButton(title: "Cancel", symbolName: "xmark", size: .small) {
                        Task { await cancelDictation() }
                    }
                }
            }
        }
    }

    private var reviewPanel: some View {
        StreamBotCard(tint: bot?.color, cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 12) {
                StreamBotSectionLabel(text: "Review", symbol: "checkmark.circle.fill")
                Text(composerViewModel.text.isEmpty ? "Nothing was heard." : composerViewModel.text)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    StreamBotActionButton(
                        title: "Send",
                        symbolName: "arrow.up",
                        isProminent: true,
                        tint: bot?.color,
                        size: .small
                    ) {
                        sendDictation()
                    }
                    .disabled(composerViewModel.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    StreamBotActionButton(title: "Keep in draft", symbolName: "pencil", size: .small) {
                        isReviewing = false
                        StreamBotHaptics.light()
                    }
                    StreamBotActionButton(title: "Discard", symbolName: "xmark", size: .small) {
                        Task { await cancelDictation() }
                    }
                }
            }
        }
    }

    // MARK: Working

    private var runStrip: some View {
        HStack(spacing: 10) {
            StreamBotThinkingDots(tint: bot?.color ?? .streamBot)
            Text(phase.label ?? "Working")
                .font(.caption.weight(.medium))
                .foregroundStyle(.streamBotSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            StreamBotActionButton(title: "Stop", symbolName: "stop.fill", size: .small) {
                StreamBotEngine.shared.cancel(in: cid)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
    }

    // MARK: Idle

    private var idleStrip: some View {
        HStack(spacing: 8) {
            if case .failed(let message) = phase {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .streamBotRepeatingSymbolEffect(for: "exclamationmark.triangle.fill")
                Spacer(minLength: 0)
            } else if let matches = skillMatches, !matches.isEmpty {
                // Typing "/" turns the strip into a skill picker, the same gesture
                // Grok Bot uses. It replaces the starter prompts rather than
                // stacking above them: one job for this strip at a time.
                ScrollView(.horizontal) {
                    HStack(spacing: 7) {
                        ForEach(matches) { skill in
                            Button {
                                insert(skill)
                            } label: {
                                Label("/\(skill.name)", systemImage: "graduationcap.fill")
                                    .font(.caption)
                                    .lineLimit(1)
                                    .streamBotRepeatingSymbolEffect(for: "graduationcap.fill")
                            }
                            .buttonStyle(.glass)
                            .buttonBorderShape(.capsule)
                            .controlSize(.small)
                            .tint(Color.primary)
                            .foregroundStyle(.primary)
                        }
                    }
                    .padding(.vertical, 1)
                }
                .scrollIndicators(.hidden)
                .contentMargins(.vertical, 2, for: .scrollContent)
            } else if composerViewModel.text.isEmpty, let bot {
                // Starter prompts, not a tutorial: a fresh thread with an
                // unfamiliar teammate is the one moment users do not know what
                // to type, and each chip is a real request for that lane.
                ScrollView(.horizontal) {
                    HStack(spacing: 7) {
                        // The one hint that the "/" gesture exists, and only when
                        // this teammate has a skill to reach for.
                        if !skills.isEmpty {
                            Button {
                                composerViewModel.text = "/"
                            } label: {
                                Label("Skills", systemImage: "graduationcap")
                                    .font(.caption)
                                    .streamBotRepeatingSymbolEffect(for: "graduationcap")
                            }
                            .buttonStyle(.glass)
                            .buttonBorderShape(.capsule)
                            .controlSize(.small)
                            .tint(Color.primary)
                            .foregroundStyle(.primary)
                        }
                        ForEach(bot.lane.starterPrompts, id: \.self) { prompt in
                            Button {
                                composerViewModel.text = prompt
                            } label: {
                                Text(prompt)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.glass)
                            .buttonBorderShape(.capsule)
                            .controlSize(.small)
                            .tint(Color.primary)
                        }
                    }
                    .padding(.vertical, 1)
                }
                .scrollIndicators(.hidden)
                // Clipped rather than free-flowing, so a long prompt slides
                // under the strip's edge instead of behind the mic button.
                .contentMargins(.vertical, 2, for: .scrollContent)
            } else {
                Spacer(minLength: 0)
            }

            StreamBotRoundButton(
                symbolName: "mic.fill",
                accessibilityLabel: "Dictate",
                tint: bot?.color,
                size: .small
            ) {
                Task { await startDictation() }
            }
        }
    }

    // MARK: Skills

    private var skills: [StreamBotSkill] {
        guard let bot else { return [] }
        return StreamBotPluginStore.shared.skills(for: bot.id)
    }

    /// The skills matching what is being typed after a "/", or nil when the user
    /// is not writing one. Nil and empty mean different things here: empty is "no
    /// skill by that name", which should keep the picker open and empty-handed
    /// rather than flipping back to starter prompts mid-word.
    private var skillMatches: [StreamBotSkill]? {
        let text = composerViewModel.text
        guard let token = text.split(separator: " ", omittingEmptySubsequences: false).last,
              token.hasPrefix("/") else { return nil }
        let query = token.dropFirst().lowercased()
        guard !skills.isEmpty else { return nil }
        return query.isEmpty
            ? skills
            : skills.filter { $0.name.lowercased().contains(query) }
    }

    /// Completes the "/" token the user started, in place.
    private func insert(_ skill: StreamBotSkill) {
        var words = composerViewModel.text.split(separator: " ", omittingEmptySubsequences: false)
        guard !words.isEmpty else { return }
        words[words.count - 1] = "/\(skill.name)"
        composerViewModel.text = words.joined(separator: " ") + " "
    }

    // MARK: Dictation control

    private func startDictation() async {
        isReviewing = false
        draftBeforeDictation = composerViewModel.text.isEmpty
            || composerViewModel.text.hasSuffix(" ")
            ? composerViewModel.text
            : composerViewModel.text + " "
        StreamBotHaptics.medium()
        await dictation.start()
    }

    private func stopRecording() async {
        let spoken = await dictation.stop()
        composerViewModel.text = (draftBeforeDictation + spoken)
            .trimmingCharacters(in: .whitespaces)
        isReviewing = !composerViewModel.text.isEmpty
        StreamBotHaptics.light()
    }

    private func sendDictation() {
        isReviewing = false
        draftBeforeDictation = ""
        StreamBotHaptics.success()
        composerViewModel.sendMessage()
    }

    private func cancelDictation() async {
        await dictation.cancel()
        composerViewModel.text = draftBeforeDictation.trimmingCharacters(in: .whitespaces)
        draftBeforeDictation = ""
        isReviewing = false
    }
}

// MARK: - Starter prompts

extension StreamBotLane {
    /// Two concrete first asks per lane. Concrete on purpose — "Summarise my
    /// unread email and flag anything urgent" teaches the shape of a good
    /// request in a way that "Ask me anything" does not.
    var starterPrompts: [String] {
        switch self {
        case .sales:
            [
                "Research Acme and draft a first outreach email",
                "Write three follow-ups for a deal that went quiet"
            ]
        case .growth:
            [
                "Draft three ad angles for a launch next week",
                "Plan a $5k test campaign and park it for review"
            ]
        case .recruiting:
            [
                "Screen this candidate against a senior iOS role",
                "Draft outreach to a staff engineer in my voice"
            ]
        case .inbox:
            [
                "Triage my unread mail and flag what is urgent",
                "Draft a polite no to a meeting request"
            ]
        case .finance:
            [
                "List the receipts I am still missing this month",
                "Code these expenses and flag anything unusual"
            ]
        case .success:
            [
                "Write a health digest for my top three accounts",
                "Draft a check-in for an account that has gone quiet"
            ]
        case .product:
            [
                "Write this week's product scoreboard",
                "What should we ship next given last week's numbers"
            ]
        case .engineering:
            [
                "Turn this bug report into clean repro steps",
                "Write a minimal reproduction for a crash on launch"
            ]
        case .research:
            [
                "What changed in my competitors' messaging this week",
                "Summarise a rival's latest launch and what it means"
            ]
        case .coordination:
            [
                "Split this project across the team and assign owners",
                "Give me one status thread for everything open"
            ]
        }
    }
}
#endif
