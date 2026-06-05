//
//  AppModel.swift
//  TrystMe
//
//  Neutral app coordinator. Owns session + cross-feature state and routes
//  intents (start a call, record a like) to the isolated Stream services.
//  Deliberately imports NO Stream module so it can be referenced everywhere.
//

import SwiftUI
import Combine

/// A request to start an outgoing ringing call, consumed by the call layer.
struct CallRequest: Identifiable, Equatable {
    let id = UUID()
    let callId: String
    let memberIds: [String]
    let video: Bool
    let calleeName: String
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    enum Phase: Equatable { case loggedOut, connecting, loggedIn }

    enum Tab: Hashable { case discover, feed, search, messages, profile }

    @Published var phase: Phase = .loggedOut
    @Published var currentUserId: String = Roster.currentUserId
    @Published var selectedTab: Tab = .discover

    /// Outgoing call request observed by the video layer in RootView.
    @Published var pendingCall: CallRequest?

    /// Local match/like bookkeeping (kept in sync with Stream where it matters).
    @Published var likedIds: Set<String> = []
    @Published var passedIds: Set<String> = []
    @Published var matchedIds: Set<String> = []
    @Published var lastMatch: Profile?

    private init() {}

    var currentProfile: Profile? { Roster.profile(currentUserId) }

    // MARK: - Session

    func login(as userId: String) async {
        guard let token = Secrets.token(for: userId),
              let profile = Roster.profile(userId) else { return }
        phase = .connecting
        currentUserId = userId

        ChatService.shared.connect(
            userId: userId, name: profile.name,
            image: profile.avatarURL.absoluteString, token: token.chat
        )
        VideoService.shared.connect(
            userId: userId, name: profile.name,
            image: profile.avatarURL.absoluteString, token: token.chat
        )
        await FeedsService.shared.connect(
            userId: userId, name: profile.name,
            image: profile.avatarURL.absoluteString, token: token.feeds
        )

        matchedIds = Set(Roster.seededMatches)
        phase = .loggedIn
        await NotificationManager.shared.requestAuthorization()
    }

    func logout() {
        ChatService.shared.disconnect()
        VideoService.shared.disconnect()
        Task { await FeedsService.shared.disconnect() }
        likedIds = []; passedIds = []; matchedIds = []; lastMatch = nil
        phase = .loggedOut
    }

    // MARK: - Discovery intents

    /// The deck of profiles still available to swipe.
    var discoverDeck: [Profile] {
        Roster.all.filter {
            $0.id != currentUserId && !likedIds.contains($0.id) && !passedIds.contains($0.id)
        }
    }

    /// Records a like. Returns `true` when it becomes a mutual match.
    @discardableResult
    func like(_ profile: Profile) -> Bool {
        likedIds.insert(profile.id)
        // Notify the other person via their Feeds notification feed.
        FeedsService.shared.sendLikeNotification(to: profile.id)

        if Roster.likesYouBack.contains(profile.id) {
            matchedIds.insert(profile.id)
            lastMatch = profile
            ChatService.shared.createMatchChannel(with: profile.id, name: profile.name)
            return true
        }
        return false
    }

    func pass(_ profile: Profile) {
        passedIds.insert(profile.id)
    }

    func isMatched(_ id: String) -> Bool { matchedIds.contains(id) }

    // MARK: - Calls

    func startCall(with profile: Profile, video: Bool) {
        startCall(withUserId: profile.id, name: profile.firstName, video: video)
    }

    func startCall(withUserId userId: String, name: String, video: Bool) {
        pendingCall = CallRequest(
            callId: "tryst-\(UUID().uuidString.prefix(8))",
            memberIds: [currentUserId, userId],
            video: video,
            calleeName: name
        )
    }
}
