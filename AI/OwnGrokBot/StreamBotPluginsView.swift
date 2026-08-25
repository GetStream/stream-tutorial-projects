#if os(iOS)
// StreamBotPluginsView.swift
// The marketplace. Two tabs, exactly as Grok Bot has it: Marketplace is what
// there is, Yours is what you added and which teammates it is on for.
//
// The Add button is the whole screen. Everything else — the categories, the
// search, the plugin page — exists to answer the two questions the user has
// before tapping it: what will this let a bot do, and what am I giving it access
// to. So a row states what it does in one line, and a page states the access in
// the plainest sentence available, before the button rather than after it.

import SwiftUI

struct StreamBotPluginsView: View {
    /// The bot this was opened from, if any. Opening the marketplace from a
    /// teammate's page makes that teammate the default target: Add switches it on
    /// there first, and Yours shows its toggles at the top.
    var bot: StreamBotTeammate?

    @Environment(\.dismiss) private var dismiss

    private let store = StreamBotPluginStore.shared
    private let roster = StreamBotRoster.shared

    private enum Tab: String, CaseIterable, Identifiable {
        case marketplace, yours
        var id: String { rawValue }
        var title: String {
            switch self {
            case .marketplace: "Marketplace"
            case .yours: "Yours"
            }
        }
    }

    @State private var tab: Tab = .marketplace
    @State private var search = ""
    @State private var category: StreamBotPluginCategory?
    @State private var selected: StreamBotPlugin?
    @State private var installing: String?
    @State private var notice: String?

    var body: some View {
        NavigationStack {
            ZStack {
                StreamBotBackdrop(tint: bot?.color ?? .streamBot)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        picker
                        if let notice {
                            StreamBotCard {
                                Text(notice)
                                    .font(.caption)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        switch tab {
                        case .marketplace: marketplace
                        case .yours: yours
                        }
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.immediately)
                // The search field floats over the bottom of the sheet, so the last
                // card needs somewhere to go when the list is scrolled to the end.
                .contentMargins(.bottom, 56, for: .scrollContent)
            }
            .navigationTitle("Plugins")
            .searchable(text: $search, prompt: "Search plugins")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .tint(.primary)
                        .foregroundStyle(.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
            }
            .sheet(item: $selected) { plugin in
                StreamBotPluginPageView(plugin: plugin, bot: bot)
            }
            .task { roster.load() }
        }
    }

    // MARK: Chrome

    private var picker: some View {
        Picker("Section", selection: $tab) {
            ForEach(Tab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    private var filterMenu: some View {
        Menu {
            Picker("Category", selection: $category) {
                Text("Everything").tag(StreamBotPluginCategory?.none)
                ForEach(StreamBotPluginCategory.allCases) { option in
                    Text(option.title).tag(StreamBotPluginCategory?.some(option))
                }
            }
        } label: {
            Image(systemName: category == nil
                ? "line.3.horizontal.decrease"
                : "line.3.horizontal.decrease.circle.fill")
        }
        .accessibilityLabel("Filter plugins")
    }

    // MARK: Marketplace

    @ViewBuilder
    private var marketplace: some View {
        let featured = matches(StreamBotPluginCatalog.featured)
        if !featured.isEmpty {
            section("Featured", plugins: featured)
        }
        ForEach(StreamBotPluginCategory.allCases) { option in
            let plugins = matches(StreamBotPluginCatalog.plugins(in: option))
            if !plugins.isEmpty {
                section(option.title, detail: option.detail, plugins: plugins)
            }
        }
        if matches(StreamBotPluginCatalog.all).isEmpty {
            StreamBotCard {
                Text("Nothing matches “\(search)”.")
                    .font(.subheadline)
                    .foregroundStyle(.streamBotSecondary)
            }
        }
        // The one thing a plugin marketplace has to be honest about on a device
        // with no browser and no server.
        Text("Every plugin here runs on this phone. Connectors read what you already have — your calendar, reminders, contacts, and threads — and nothing is uploaded to be read. There is no plugin for a system this app cannot reach.")
            .font(.caption)
            .foregroundStyle(.streamBotSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
    }

    @ViewBuilder
    private func section(
        _ title: String,
        detail: String? = nil,
        plugins: [StreamBotPlugin]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.streamBotSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            StreamBotCard {
                VStack(spacing: 14) {
                    ForEach(plugins) { plugin in
                        StreamBotPluginRow(
                            plugin: plugin,
                            isInstalled: store.isInstalled(plugin),
                            isInstalling: installing == plugin.id,
                            open: { selected = plugin },
                            add: { add(plugin) }
                        )
                    }
                }
            }
        }
    }

    // MARK: Yours

    @ViewBuilder
    private var yours: some View {
        let installed = matches(store.installed)
        if installed.isEmpty {
            StreamBotCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nothing added yet")
                        .font(.subheadline.weight(.semibold))
                    Text("Add a plugin from the Marketplace and it appears here, with a switch for every teammate.")
                        .font(.caption)
                        .foregroundStyle(.streamBotSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            ForEach(installed) { plugin in
                StreamBotCard(tint: plugin.accent.color) {
                    VStack(alignment: .leading, spacing: 12) {
                        StreamBotPluginRow(
                            plugin: plugin,
                            isInstalled: true,
                            isInstalling: false,
                            open: { selected = plugin },
                            add: {}
                        )
                        Divider().opacity(0.6)
                        Text("On for")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.streamBotSecondary)
                        // The bot this sheet was opened from goes first: it is the
                        // one the user came here to change.
                        ForEach(orderedRoster) { teammate in
                            Toggle(isOn: binding(plugin: plugin, botId: teammate.id)) {
                                HStack(spacing: 8) {
                                    StreamBotAvatar(
                                        symbolName: teammate.symbolName,
                                        accent: teammate.color,
                                        size: 26
                                    )
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(teammate.shortName)
                                            .font(.subheadline)
                                        Text(teammate.roleName)
                                            .font(.caption)
                                            .foregroundStyle(.streamBotSecondary)
                                    }
                                }
                            }
                            .tint(plugin.accent.color)
                        }
                    }
                }
            }
        }
    }

    private var orderedRoster: [StreamBotTeammate] {
        guard let bot else { return roster.bots }
        return [bot] + roster.bots.filter { $0.id != bot.id }
    }

    private func binding(plugin: StreamBotPlugin, botId: String) -> Binding<Bool> {
        Binding(
            get: { store.isEnabled(plugin, for: botId) },
            set: { store.setEnabled($0, plugin: plugin, botId: botId) }
        )
    }

    // MARK: Actions

    private func matches(_ plugins: [StreamBotPlugin]) -> [StreamBotPlugin] {
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return plugins.filter { plugin in
            (category == nil || plugin.category == category)
                && (term.isEmpty
                    || plugin.name.lowercased().contains(term)
                    || plugin.tagline.lowercased().contains(term)
                    || plugin.skills.contains { $0.name.lowercased().contains(term) })
        }
    }

    private func add(_ plugin: StreamBotPlugin) {
        installing = plugin.id
        notice = nil
        Task {
            // Adding from a teammate's page switches it on there whatever its lane
            // suggests — the user asked for it from that bot.
            let outcome = await store.install(plugin)
            if let bot { store.setEnabled(true, plugin: plugin, botId: bot.id) }
            installing = nil
            switch outcome {
            case .installed:
                notice = "Added. \(plugin.name) is ready in this app."
                tab = .yours
                StreamBotHaptics.success()
            case .installedWithoutPermission(let reason), .failed(let reason):
                notice = reason
            }
        }
    }
}

// MARK: - Row

struct StreamBotPluginRow: View {
    let plugin: StreamBotPlugin
    let isInstalled: Bool
    let isInstalling: Bool
    let open: () -> Void
    let add: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: open) {
                HStack(spacing: 12) {
                    StreamBotAvatar(
                        symbolName: plugin.symbolName,
                        accent: plugin.accent.color,
                        size: 38
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plugin.name)
                            .font(.subheadline.weight(.semibold))
                        Text(plugin.tagline)
                            .font(.caption)
                            .foregroundStyle(.streamBotSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if isInstalled {
                Label("Added", systemImage: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .labelStyle(.titleAndIcon)
            } else if isInstalling {
                ProgressView().controlSize(.small)
            } else {
                StreamBotActionButton(title: "Add", size: .small, action: add)
            }
        }
    }
}

// MARK: - Plugin page

/// One plugin, in full: what it installs, what it needs, and who has it.
struct StreamBotPluginPageView: View {
    let plugin: StreamBotPlugin
    var bot: StreamBotTeammate?

    @Environment(\.dismiss) private var dismiss

    private let store = StreamBotPluginStore.shared
    private let roster = StreamBotRoster.shared

    @State private var isInstalling = false
    @State private var notice: String?

    private var isInstalled: Bool { store.isInstalled(plugin) }

    var body: some View {
        NavigationStack {
            ZStack {
                StreamBotBackdrop(tint: plugin.accent.color)
                ScrollView {
                    VStack(spacing: 14) {
                        header
                        if let connector = plugin.connector {
                            access(connector)
                        }
                        if !plugin.skills.isEmpty {
                            skills
                        }
                        if isInstalled {
                            StreamBotCard {
                                HStack {
                                    Text("On for \(store.enabledCount(for: plugin)) of \(roster.bots.count) teammates")
                                        .font(.caption)
                                        .foregroundStyle(.streamBotSecondary)
                                    Spacer(minLength: 0)
                                    Button("Remove", role: .destructive) {
                                        store.uninstall(plugin)
                                        dismiss()
                                    }
                                    .font(.caption.weight(.semibold))
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.red)
                                }
                            }
                        }
                        if let notice {
                            Text(notice)
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(plugin.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .tint(.primary)
                        .foregroundStyle(.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isInstalled {
                        Label("Added", systemImage: "checkmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    } else {
                        StreamBotActionButton(
                            title: "Add",
                            isProminent: true,
                            tint: plugin.accent.color,
                            size: .small,
                            isBusy: isInstalling
                        ) {
                            install()
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        StreamBotCard(tint: plugin.accent.color) {
            HStack(spacing: 14) {
                StreamBotAvatar(
                    symbolName: plugin.symbolName,
                    accent: plugin.accent.color,
                    size: 52
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(plugin.category.title)
                        .font(.caption.weight(.semibold))
                        .streamBotAccentText(plugin.accent.color)
                    Text(plugin.tagline)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func access(_ connector: StreamBotConnector) -> some View {
        StreamBotCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("What it reads", systemImage: "lock.open")
                    .font(.subheadline.weight(.semibold))
                Text(connector.summary)
                    .font(.caption)
                    .foregroundStyle(.streamBotSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    StreamBotPill(text: "Read-only", symbolName: "eye")
                    if let permission = connector.permission.title {
                        StreamBotPill(
                            text: permission,
                            symbolName: StreamBotPluginStore.isPermitted(connector.permission)
                                ? "checkmark.shield"
                                : "exclamationmark.shield",
                            tint: StreamBotPluginStore.isPermitted(connector.permission)
                                ? .green
                                : .orange
                        )
                    }
                    StreamBotPill(text: "On device", symbolName: "iphone")
                }
                Text("The bot calls this during a run, the same way it would open an app. The model runs on this phone, so what it reads stays here.")
                    .font(.caption)
                    .foregroundStyle(.streamBotSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var skills: some View {
        StreamBotCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(
                    plugin.skills.count == 1 ? "1 skill" : "\(plugin.skills.count) skills",
                    systemImage: "graduationcap"
                )
                .font(.subheadline.weight(.semibold))
                ForEach(plugin.skills) { skill in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("/\(skill.name)")
                                .font(.subheadline.weight(.semibold))
                                .streamBotAccentText(plugin.accent.color)
                        }
                        Text(skill.summary)
                            .font(.caption)
                            .foregroundStyle(.streamBotSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if skill.id != plugin.skills.last?.id {
                        Divider().opacity(0.6)
                    }
                }
                Text("Skills go into the bot's instructions when the work matches, and can be asked for by name with “/” in the composer.")
                    .font(.caption)
                    .foregroundStyle(.streamBotSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func install() {
        isInstalling = true
        Task {
            let outcome = await store.install(plugin)
            if let bot { store.setEnabled(true, plugin: plugin, botId: bot.id) }
            isInstalling = false
            switch outcome {
            case .installed:
                notice = "Added. \(plugin.name) is ready in this app."
                StreamBotHaptics.success()
                try? await Task.sleep(for: .milliseconds(650))
                dismiss()
            case .installedWithoutPermission(let reason), .failed(let reason):
                notice = reason
            }
        }
    }
}
#endif
