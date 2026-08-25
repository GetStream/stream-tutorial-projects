#if os(iOS)
// StreamBotRootView.swift
// The app shell: four tabs, and the one place the Stream client is started.
//
// Threads / Team / Models / Settings is the whole navigation. Threads is Stream's
// channel list wearing StreamBot's view factory; Team is the roster; Models is
// which on-device model the bots think with; Settings is haptics, notifications,
// scheduled-routine timezone, and reconnecting the on-device runtime.

import Foundation
import FoundationModels
import StreamChat
import StreamChatSwiftUI
import SwiftUI

struct StreamBotRootView: View {
    /// Named `Screen`, not `Tab`: a nested `Tab` would shadow SwiftUI's own
    /// `Tab` view inside this type and the `TabView` below would not compile.
    enum Screen: Hashable {
        case threads, team, models, settings
    }

    @State private var screen: Screen = .threads
    @Environment(\.scenePhase) private var scenePhase
    private let shareIntake = StreamBotShareIntake.shared

    init() {
        // Before any Stream view can be constructed: `StreamChat` installs the
        // appearance and injected dependencies the SDK's views resolve at init.
        StreamBotChatService.shared.setUpIfNeeded()
        StreamBotMessageWatcher.shared.start()
        Self.padTabBarLabels()
    }

    /// Gives the tab titles a little room.
    ///
    /// The floating tab bar draws its selection capsule around the label and
    /// insets it by a fixed amount, so a title wider than its icon sits flush
    /// against the capsule's edge. SwiftUI has no way in — padding applied to a
    /// `Tab`'s label is dropped — so the item metrics are adjusted through
    /// UIKit's appearance proxy, mutating the appearance the system already
    /// installed rather than a fresh one, which would take the glass with it.
    private static func padTabBarLabels() {
        let appearance = UITabBar.appearance().standardAppearance
        for item in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ] {
            for state in [item.normal, item.selected, item.focused, item.disabled] {
                state.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: -1)
            }
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $screen) {
            Tab(value: Screen.threads) {
                StreamBotThreadsTab()
                    .tint(.primary)
            } label: {
                tabLabel("Threads", symbol: "bubble.left.and.text.bubble.right")
                    .streamBotRepeatingSymbolEffect(for: "bubble.left.and.text.bubble.right")
            }
            Tab(value: Screen.team) {
                StreamBotRosterView()
                    .tint(.primary)
            } label: {
                tabLabel("Team", symbol: "person.2")
            }
            Tab(value: Screen.models) {
                StreamBotModelsTab()
                    .tint(.primary)
            } label: {
                tabLabel("Models", symbol: "cpu")
            }
            Tab(value: Screen.settings) {
                StreamBotSettingsView()
                    .tint(.primary)
            } label: {
                tabLabel("Settings", symbol: "gearshape")
                    .streamBotRepeatingSymbolEffect(for: "gearshape")
            }
        }
        // The system tab bar is already Liquid Glass on iOS 26+. Minimising it on
        // scroll is what keeps a thread readable on a small phone: the glass bar
        // shrinks out of the way of the message list and comes back on scroll up.
        .tabBarMinimizeBehavior(.onScrollDown)
        // Brand blue on the tab bar; screens inside each tab use `.primary` so
        // Close, Save, and glass chips stay ink rather than `#005fff` type.
        .tint(.streamBot)
        .overlay(alignment: .top) {
            StreamBotLearningBanner()
        }
        .sheet(item: Binding(
            get: { shareIntake.pending },
            set: { shareIntake.pending = $0 }
        )) { payload in
            StreamBotShareHandoffSheet(payload: payload)
        }
        .onOpenURL { shareIntake.handle(url: $0) }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL {
                StreamBotShareIntake.shared.handle(url: url)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                StreamBotScheduler.fireDueRoutines()
            }
        }
        // Loaded here rather than on the Team tab alone: the thread list and the
        // view factory resolve every message's author against the roster, so it
        // has to be populated before the first channel row is drawn.
        .task {
            StreamBotRoster.shared.load()
            StreamBotScheduler.fireDueRoutines()
        }
    }

    /// A tab's icon and title, with room either side of the title.
    ///
    /// The thin spaces are the padding: the tab bar measures the title and insets
    /// it by a fixed amount, so widening the title is the only way to move it off
    /// the selection capsule's edge. They are not spoken by VoiceOver.
    private func tabLabel(_ title: String, symbol: String) -> some View {
        Label("\u{2009}\(title)\u{2009}", systemImage: symbol)
    }
}

// MARK: - Threads

/// Stream's channel list, filtered to this app's channels and rendered through
/// `StreamBotViewFactory`.
struct StreamBotThreadsTab: View {
    /// Built once and held: the controller owns the query and its pagination
    /// state, and rebuilding it on every body pass would reset the list's
    /// scroll position and refetch page one.
    @State private var controller: ChatChannelListController?

    var body: some View {
        Group {
            if let controller {
                ChatChannelListView(
                    viewFactory: StreamBotViewFactory.shared,
                    channelListController: controller,
                    title: "Threads",
                    handleTabBarVisibility: false
                )
            } else {
                ProgressView()
            }
        }
        .onAppear {
            guard controller == nil, let client = StreamBotChatService.shared.chatClient else { return }
            controller = client.channelListController(
                query: StreamBotChatService.shared.channelListQuery
            )
        }
    }
}

// MARK: - Models

/// Which model the team thinks with, and the place to fetch the ones that are
/// not on the phone yet.
struct StreamBotModelsTab: View {
    private let preferences = AIModelPreferences.shared

    @State private var downloader = ModelDownloader()
    /// Which bundles are on disk. A file-system check, so it is held as state and
    /// re-read when a download finishes rather than consulted from `body`.
    @State private var installed: Set<String> = []
    /// Why a download failed, per model, so the message stays on the row that
    /// tried rather than on whichever row happens to render next.
    @State private var failures: [String: String] = [:]

    var body: some View {
        NavigationStack {
            ZStack {
                StreamBotBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        StreamBotEditorialHeader(
                            eyebrow: "On this device",
                            title: "Models",
                            detail: "Your bots' reasoning, their drafts, and your dictation never leave the phone. Only the chat itself goes through Stream."
                        )

                        StreamBotCard {
                            VStack(alignment: .leading, spacing: 14) {
                                StreamBotSectionLabel(text: "Thinking", symbol: "cpu")
                                ForEach(AIModelPreferences.textChoices) { choice in
                                    StreamBotModelRow(
                                        choice: choice,
                                        isSelected: choice.id == preferences.textModel.id,
                                        isInstalled: isInstalled(choice),
                                        failure: failure(for: choice),
                                        downloader: downloader,
                                        select: { preferences.textModel = choice },
                                        download: { fetch($0) }
                                    )
                                    if choice.id != AIModelPreferences.textChoices.last?.id {
                                        Divider().opacity(0.45)
                                    }
                                }
                            }
                        }

                        StreamBotCard {
                            VStack(alignment: .leading, spacing: 10) {
                                StreamBotSectionLabel(text: "Dictation", symbol: "waveform")
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "waveform")
                                        .font(.title3)
                                        .streamBotAccentText(.streamBot)
                                        .streamBotRepeatingSymbolEffect(for: "waveform")
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("SpeechAnalyzer")
                                            .font(.subheadline.weight(.semibold))
                                        Text("Apple's on-device SpeechTranscriber. Record and send are separate on purpose — you review the words before they go to a teammate. The language model downloads on first use.")
                                            .font(.caption)
                                            .foregroundStyle(.streamBotSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .task { refreshInstalled() }
        }
    }

    private func isInstalled(_ choice: ChatModelChoice) -> Bool {
        switch choice {
        case .appleFoundationModel: true
        case .zoo(let model): installed.contains(model.id)
        }
    }

    /// Fetches a bundle and hands the team over to it.
    ///
    /// Selecting it afterwards is the point: nobody downloads 1.3 GB of model to
    /// then go and tap it. If the download fails the selection is left alone and
    /// the row says what went wrong.
    private func fetch(_ model: ZooModel) {
        failures[model.id] = nil
        Task {
            await downloader.fetch(model: model)
            refreshInstalled()
            if installed.contains(model.id) {
                preferences.textModel = .zoo(model)
            } else if case .failed(let message) = downloader.phase {
                failures[model.id] = message
            }
        }
    }

    private func failure(for choice: ChatModelChoice) -> String? {
        switch choice {
        case .appleFoundationModel: nil
        case .zoo(let model): failures[model.id]
        }
    }

    private func refreshInstalled() {
        installed = Set(ZooModelCatalog.all.filter { ZooModelCatalog.isInstalled($0) }.map(\.id))
    }
}

struct StreamBotModelRow: View {
    let choice: ChatModelChoice
    let isSelected: Bool
    let isInstalled: Bool
    let failure: String?
    let downloader: ModelDownloader
    let select: () -> Void
    let download: (ZooModel) -> Void

    private var zoo: ZooModel? {
        switch choice {
        case .appleFoundationModel: nil
        case .zoo(let model): model
        }
    }

    /// Whether this model can be picked right now. A bundle that is not on the
    /// phone is offered for download instead of being selectable, because letting
    /// it be picked would fail at the first message rather than here.
    private var isUsable: Bool {
        switch choice {
        case .appleFoundationModel:
            SystemLanguageModel.default.availability == .available
        case .zoo:
            isInstalled
        }
    }

    private var isFetchingThis: Bool {
        downloader.activeModelID != nil && downloader.activeModelID == zoo?.id
    }

    private var detail: String {
        switch choice {
        case .appleFoundationModel:
            switch SystemLanguageModel.default.availability {
            case .available:
                "Guided generation, so plans and routines cannot come back malformed."
            case .unavailable(.appleIntelligenceNotEnabled):
                "Switch on Apple Intelligence in Settings to use this."
            case .unavailable(.modelNotReady):
                "Still downloading. It becomes usable once iOS finishes."
            case .unavailable:
                "Not supported on this device."
            }
        case .zoo(let model):
            isInstalled
                ? model.detail
                : "\(model.family). \(model.detail)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tapping a model that is not here yet fetches it, which is what the
            // tap meant. The row is never dimmed for it either: greying out the
            // one thing on the screen that explains a model is how the list ended
            // up unreadable and looking broken.
            Button {
                if isUsable {
                    StreamBotHaptics.selection()
                    select()
                } else if let model = zoo, !downloader.busy {
                    download(model)
                }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: choice.symbolName)
                        .font(.subheadline)
                        .streamBotAccentText(isUsable ? .streamBot : .streamBotSecondary)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(choice.displayName)
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.streamBotSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .streamBotAccentText(.streamBot)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            // Only Apple's model can be neither pickable nor fetchable: when it is
            // off, the fix is in Settings and there is nothing to tap here.
            .disabled(!isUsable && zoo == nil)

            if let model = zoo, !isInstalled {
                if isFetchingThis, downloader.busy {
                    VStack(alignment: .leading, spacing: 5) {
                        StreamBotProgressTrack(fraction: downloader.fraction)
                        HStack(spacing: 6) {
                            Text(progressLabel)
                            Spacer(minLength: 0)
                            Text("\(Int(downloader.fraction * 100))%")
                                .monospacedDigit()
                        }
                        .font(.caption)
                        .foregroundStyle(.streamBotSecondary)
                    }
                } else {
                    HStack(spacing: 8) {
                        StreamBotActionButton(
                            title: failure == nil ? "Get \(model.approximateSize)" : "Try again",
                            symbolName: "arrow.down.circle",
                            size: .small
                        ) {
                            download(model)
                        }
                        // One at a time: the bundles are gigabytes and only one
                        // can be loaded into the GPU afterwards anyway.
                        .disabled(downloader.busy)
                        Text(model.license)
                            .font(.caption)
                            .foregroundStyle(.streamBotSecondary)
                        Spacer(minLength: 0)
                    }
                }
            }

            if let failure {
                Text(failure)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
        .animation(.smooth(duration: 0.25), value: isFetchingThis)
    }

    private var progressLabel: String {
        switch downloader.phase {
        case .listing: "Listing files…"
        case .downloading: downloader.detail.isEmpty ? "Downloading…" : downloader.detail
        default: "Finishing…"
        }
    }
}

// MARK: - Learning banner

/// Reports the result of "Teach as routine", which finishes long after the menu
/// that started it has gone. Presented from the root so it is visible whichever
/// tab the user wandered to.
struct StreamBotLearningBanner: View {
    private let teach = StreamBotTeachCoordinator.shared

    var body: some View {
        Group {
            switch teach.state {
            case .idle:
                EmptyView()
            case .learning(let name):
                banner {
                    ProgressView().controlSize(.mini)
                    Text("\(name) is writing down the routine…")
                }
            case .learned(let name):
                banner {
                    Image(systemName: "graduationcap.fill")
                        .foregroundStyle(.green)
                        .streamBotRepeatingSymbolEffect(for: "graduationcap.fill")
                    Text("Learned “\(name)”")
                }
            case .failed(let message):
                banner {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .streamBotRepeatingSymbolEffect(for: "exclamationmark.triangle.fill")
                    Text(message).lineLimit(2)
                }
            }
        }
        .animation(.smooth(duration: 0.3), value: teach.state)
    }

    @ViewBuilder
    private func banner(@ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: 8) {
            content()
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .padding(.top, 6)
        .transition(.move(edge: .top).combined(with: .opacity))
        .task(id: teach.state) {
            // Success and failure clear themselves; "learning" stays until the
            // model is done.
            switch teach.state {
            case .learned, .failed:
                try? await Task.sleep(for: .seconds(3))
                teach.dismiss()
            default:
                break
            }
        }
    }
}
#endif
