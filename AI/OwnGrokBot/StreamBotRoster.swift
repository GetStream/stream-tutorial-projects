#if os(iOS)
// StreamBotRoster.swift
// Who the user's teammates are.
//
// The roster is read from Stream rather than hard-coded, so a bot created on the
// iPhone shows up on the iPad without the app shipping a new build. Bots are
// ordinary Stream users tagged `kind: "bot"` / `app: "owngrokbot"`, which means
// one user query returns the whole team.
//
// The presets are used as a first frame, not as a fallback of last resort: the
// eight seeded teammates have deterministic ids (`grok-<preset id>`), so the
// roster can be rendered correctly before the network answers and then be
// replaced by the authoritative version. Users never see an empty team screen,
// and a bot the user renamed still shows its real name once the query lands.

import Foundation
import Observation
import StreamChat

@MainActor
@Observable
final class StreamBotRoster {
    static let shared = StreamBotRoster()

    private(set) var bots: [StreamBotTeammate] = []
    private(set) var isLoading = false
    private(set) var loadError: String?

    /// Lookup used by the view factory on every message, so it is a dictionary
    /// rather than a linear search through the array.
    private(set) var byId: [String: StreamBotTeammate] = [:]

    private var controller: ChatUserListController?

    private init() {
        apply(Self.seededBots, isAuthoritative: false)
    }

    func bot(id: String?) -> StreamBotTeammate? {
        guard let id else { return nil }
        return byId[id]
    }

    /// Refreshes the team from Stream. Safe to call on every appearance of the
    /// roster screen; it replaces the query's results wholesale.
    func load() {
        guard let client = StreamBotChatService.shared.chatClient, !isLoading else { return }
        isLoading = true
        loadError = nil

        let controller = client.userListController(
            query: UserListQuery(
                filter: .and([
                    .equal("kind", to: "bot"),
                    .equal("app", to: StreamBotTeammate.appMarker)
                ]),
                sort: [.init(key: .id, isAscending: true)],
                pageSize: 50
            )
        )
        self.controller = controller

        controller.synchronize { [weak self] (error: Error?) in
            guard let self else { return }
            isLoading = false
            if let error {
                loadError = error.localizedDescription
                return
            }
            let found = controller.users.compactMap(StreamBotTeammate.init(user:))
            // An empty result means the query worked but nothing is seeded yet —
            // keep the presets on screen rather than blanking the team.
            guard !found.isEmpty else { return }
            apply(found, isAuthoritative: true)
        }
    }

    /// Adds a bot the user just created, so it appears before the next refresh.
    func insert(_ bot: StreamBotTeammate) {
        var next = bots.filter { $0.id != bot.id }
        next.append(bot)
        apply(next, isAuthoritative: true)
    }

    private func apply(_ incoming: [StreamBotTeammate], isAuthoritative: Bool) {
        // Presets and Stream results are merged by id so a locally created bot
        // is not dropped by a refresh that ran before Stream indexed it.
        var merged: [String: StreamBotTeammate] = isAuthoritative
            ? Dictionary(uniqueKeysWithValues: Self.seededBots.map { ($0.id, $0) })
            : [:]
        for bot in incoming { merged[bot.id] = bot }

        byId = merged
        bots = merged.values.sorted { lhs, rhs in
            if lhs.lane == rhs.lane { return lhs.shortName < rhs.shortName }
            return lhs.lane.sortIndex < rhs.lane.sortIndex
        }
    }

    /// The teammates seeded into Stream, rebuilt locally from the presets they
    /// were created from. Hire-only roles (Paid Media, Product Performance) stay
    /// off this list until the user actually hires them.
    static var seededBots: [StreamBotTeammate] {
        let seeded = Set(["nova", "sales", "talent", "inbox", "expense", "invoice", "account", "bugs", "compete"])
        return StreamBotPreset.all
            .filter { seeded.contains($0.id) }
            .map { $0.makeBot(userId: "grok-\($0.id)") }
    }
}

extension StreamBotLane {
    /// Fixed display order for the roster, so the team does not reshuffle
    /// alphabetically every time a bot is renamed.
    var sortIndex: Int {
        switch self {
        case .inbox: 0
        case .sales: 1
        case .growth: 2
        case .recruiting: 3
        case .product: 4
        case .finance: 5
        case .success: 6
        case .engineering: 7
        case .research: 8
        case .coordination: 9
        }
    }
}
#endif
