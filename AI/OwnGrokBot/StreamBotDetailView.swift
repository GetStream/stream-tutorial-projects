#if os(iOS)
// StreamBotDetailView.swift
// Everything a teammate is, in one sheet: what it is allowed to do, what it has
// been told, what it has learned, and what it remembers.
//
// The four sections are the four ways a user can change a bot's behaviour, in
// the order they reach for them. Policy first because it is the one with
// consequences; memory last because it is the one the bot manages itself and the
// user only visits to delete something wrong.

import StreamChat
import SwiftUI

struct StreamBotDetailView: View {
    let bot: StreamBotTeammate
    let cid: ChannelId

    @Environment(\.dismiss) private var dismiss

    // Plain references, not `@State`: these are `@Observable` singletons, and
    // reading their properties inside `body` is what registers the dependency.
    private let store = StreamBotStore.shared
    private let teach = StreamBotTeachCoordinator.shared
    private let plugins = StreamBotPluginStore.shared

    @State private var instructions = ""
    @State private var approval: StreamBotApprovalPolicy = .queueUntilApproved
    @State private var saveError: String?
    @State private var isSaving = false
    @State private var isBrowsingPlugins = false

    var body: some View {
        NavigationStack {
            ZStack {
                StreamBotBackdrop(tint: bot.color)
                ScrollView {
                    VStack(spacing: 16) {
                        identity
                        policySection
                        pluginsSection
                        instructionsSection
                        routinesSection
                        memorySection
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(bot.shortName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .tint(.primary)
                        .foregroundStyle(.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    StreamBotActionButton(
                        title: "Save",
                        isProminent: true,
                        tint: bot.color,
                        size: .small,
                        isBusy: isSaving
                    ) {
                        Task { await save() }
                    }
                    .disabled(!hasChanges)
                }
            }
            .alert(
                "Could not save",
                isPresented: .init(
                    get: { saveError != nil },
                    set: { if !$0 { saveError = nil } }
                )
            ) {
                Button("OK") { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
            .sheet(isPresented: $isBrowsingPlugins) {
                StreamBotPluginsView(bot: bot)
            }
        }
        .onAppear {
            instructions = store.instructions(for: bot.id)
            approval = bot.approval
        }
    }

    private var hasChanges: Bool {
        instructions != store.instructions(for: bot.id) || approval != bot.approval
    }

    /// The surfaces a plugin genuinely opens for this bot.
    private var live: Set<StreamBotWorkspace> {
        Set(plugins.connectors(for: bot.id).compactMap(\.surface))
    }

    /// Declared surfaces first, then any live one the seed never declared —
    /// Threads is nobody's declared surface but every bot can search it.
    private var surfaces: [StreamBotWorkspace] {
        bot.workspaces + live.subtracting(bot.workspaces).sorted { $0.title < $1.title }
    }

    // MARK: Identity

    private var identity: some View {
        StreamBotCard(tint: bot.color) {
            HStack(spacing: 14) {
                StreamBotAvatar(symbolName: bot.symbolName, accent: bot.color, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(bot.roleName)
                        .font(.headline)
                    Text(bot.tagline)
                        .font(.footnote)
                        .foregroundStyle(.streamBotSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Policy

    private var policySection: some View {
        StreamBotCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("How far it can go", symbol: "hand.raised")
                // A Picker rather than three buttons: these are mutually
                // exclusive and the user needs to see which one is in force
                // without reading three descriptions.
                Picker("Approval policy", selection: $approval) {
                    ForEach(StreamBotApprovalPolicy.allCases) { policy in
                        Text(policy.title).tag(policy)
                    }
                }
                .pickerStyle(.segmented)
                Text(approval.detail)
                    .font(.footnote)
                    .foregroundStyle(.streamBotSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle("Notify me about this bot", isOn: Binding(
                    get: { StreamBotPreferences.shared.notificationsEnabled(for: bot.id) },
                    set: { enabled in
                        if enabled, !StreamBotPreferences.shared.notificationsEnabled {
                            Task { _ = await StreamBotNotifications.requestAuthorization() }
                        }
                        StreamBotPreferences.shared.setNotificationsEnabled(enabled, for: bot.id)
                    }
                ))
                .font(.subheadline)
                .tint(bot.color)

                if !surfaces.isEmpty {
                    Divider().padding(.vertical, 2)
                    Text("Surfaces")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.streamBotSecondary)
                    // Two kinds of surface now sit side by side, and conflating
                    // them would be the one dishonest sentence in the app: a plugin
                    // makes a surface real, everything else only names where a step
                    // belongs.
                    Text(live.isEmpty
                        ? "Steps can be attributed to these. Nothing is logged into — this bot runs on your device with no network access."
                        : "The ones in colour are live: a plugin reads them on this device. The rest only name where a step belongs — nothing is logged into.")
                        .font(.caption)
                        .foregroundStyle(.streamBotSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    // Scrolls rather than wraps: a bot with three declared surfaces
                    // and two live ones is wider than a phone.
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(surfaces) { surface in
                                StreamBotPill(
                                    text: surface.title,
                                    symbolName: surface.symbolName,
                                    tint: live.contains(surface) ? bot.color : nil
                                )
                            }
                        }
                        .padding(.vertical, 1)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
    }

    // MARK: Plugins

    /// What this teammate can reach, and how to give it more.
    ///
    /// Deliberately the same toggle the marketplace's Yours tab shows, and not a
    /// second idea of enablement: a plugin is added once for the team and switched
    /// on per bot, so this section is the per-bot half of one setting.
    private var pluginsSection: some View {
        StreamBotCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    sectionTitle("Plugins", symbol: "puzzlepiece.extension")
                    Spacer()
                    StreamBotActionButton(title: "Browse", symbolName: "plus", size: .small) {
                        isBrowsingPlugins = true
                    }
                }

                let installed = plugins.installed
                if installed.isEmpty {
                    Text("Plugins give this bot real sources to read — your calendar, reminders, contacts, threads — and packaged ways of working. Nothing is added yet.")
                        .font(.caption)
                        .foregroundStyle(.streamBotSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(installed) { plugin in
                        Toggle(isOn: Binding(
                            get: { plugins.isEnabled(plugin, for: bot.id) },
                            set: { plugins.setEnabled($0, plugin: plugin, botId: bot.id) }
                        )) {
                            HStack(spacing: 10) {
                                Image(systemName: plugin.symbolName)
                                    .font(.subheadline)
                                    .streamBotAccentText(plugin.accent.color)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(plugin.name)
                                        .font(.subheadline)
                                    Text(plugin.connector == nil
                                        ? "\(plugin.skills.count == 1 ? "1 skill" : "\(plugin.skills.count) skills")"
                                        : plugin.connector!.summary)
                                        .font(.caption)
                                        .foregroundStyle(.streamBotSecondary)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .tint(bot.color)
                    }
                    if !AIModelPreferences.shared.textModel.supportsToolCalling {
                        Text("Connectors need Apple Intelligence — the Core AI models can't call them. Skills still work on any model.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: Instructions

    private var instructionsSection: some View {
        StreamBotCard {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("Standing instructions", symbol: "text.quote")
                // The example lives here rather than in the field's placeholder:
                // placeholder text on glass is the dimmest thing on the screen,
                // and this is the sentence that shows the user what to write.
                Text("Added to everything this bot does — tone, format, who to copy, what to never do. For example: keep drafts under 120 words and never use exclamation marks.")
                    .font(.caption)
                    .foregroundStyle(.streamBotSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                TextField(
                    "",
                    text: $instructions,
                    prompt: Text("Add an instruction").foregroundStyle(Color.streamBotTertiary),
                    axis: .vertical
                )
                .lineLimit(3...8)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .padding(10)
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
            }
        }
    }

    // MARK: Routines

    private var routinesSection: some View {
        StreamBotCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    sectionTitle("Routines", symbol: "graduationcap")
                    Spacer()
                    if case .learning = teach.state {
                        ProgressView().controlSize(.mini)
                    } else {
                        StreamBotActionButton(title: "Teach", symbolName: "plus", size: .small) {
                            teach.teach(bot: bot, in: cid)
                        }
                    }
                }

                let routines = store.routines(for: bot.id)
                if routines.isEmpty {
                    Text("Do the work once in the thread, then tap Teach. \(bot.shortName) writes down the steps and runs them itself next time.")
                        .font(.caption)
                        .foregroundStyle(.streamBotSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(routines) { routine in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(routine.name)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                if routine.runCount > 0 {
                                    StreamBotPill(text: "ran \(routine.runCount)×", tint: bot.color)
                                }
                                Button {
                                    store.delete(routineId: routine.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundStyle(.streamBotSecondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Delete routine")
                            }
                            if !routine.trigger.isEmpty {
                                Text(routine.trigger)
                                    .font(.caption)
                                    .foregroundStyle(.streamBotSecondary)
                            }
                            ForEach(Array(routine.steps.enumerated()), id: \.offset) { index, step in
                                Text("\(index + 1). \(step)")
                                    .font(.caption)
                                    .foregroundStyle(.streamBotSecondary)
                            }
                            Toggle("Enabled", isOn: Binding(
                                get: { routine.isEnabled },
                                set: { store.setEnabled($0, routineId: routine.id) }
                            ))
                            .font(.caption.weight(.semibold))
                            .tint(bot.color)
                            Toggle("Run on a schedule", isOn: Binding(
                                get: { routine.scheduleHour != nil },
                                set: { store.setSchedule(hour: $0 ? 8 : nil, routineId: routine.id) }
                            ))
                            .font(.caption.weight(.semibold))
                            .tint(bot.color)
                            if routine.scheduleHour != nil {
                                Picker("Hour", selection: Binding(
                                    get: { routine.scheduleHour ?? 8 },
                                    set: { store.setSchedule(hour: $0, routineId: routine.id) }
                                )) {
                                    ForEach(6..<22, id: \.self) { hour in
                                        Text(hourLabel(hour)).tag(hour)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.primary)
                                Text("Fires the next time you open StreamBot after this hour. Bots think on this device, so they cannot run while the phone is asleep.")
                                    .font(.caption2)
                                    .foregroundStyle(.streamBotSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                        if routine.id != routines.last?.id {
                            Divider()
                        }
                    }
                }

                if case .failed(let message) = teach.state {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: Memory

    private var memorySection: some View {
        StreamBotCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    sectionTitle("What it remembers", symbol: "brain")
                    Spacer()
                    if !store.memories(for: bot.id).isEmpty {
                        Button("Forget all") { store.forgetAll(for: bot.id) }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                    }
                }

                let memories = store.memories(for: bot.id)
                if memories.isEmpty {
                    Text("Picked up from how you work, and kept on this device only.")
                        .font(.caption)
                        .foregroundStyle(.streamBotSecondary)
                } else {
                    ForEach(memories) { memory in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: memory.kind.symbolName)
                                .font(.caption)
                                .streamBotAccentText(bot.color)
                                .frame(width: 16)
                            Text(memory.text)
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Button {
                                store.forget(memoryId: memory.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .foregroundStyle(.streamBotSecondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Forget this")
                        }
                    }
                }
            }
        }
    }

    // MARK: Bits

    private func sectionTitle(_ text: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
            Text(text)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.primary)
    }

    private func hourLabel(_ hour: Int) -> String {
        let suffix = hour >= 12 ? "PM" : "AM"
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        return "\(twelve):00 \(suffix)"
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        store.setInstructions(instructions, for: bot.id)

        guard approval != bot.approval else {
            dismiss()
            return
        }
        var updated = bot
        updated.approval = approval
        do {
            try await StreamBotSender.shared.updateProfile(updated)
            StreamBotRoster.shared.insert(updated)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
#endif
