//
//  FeedsService.swift
//  OOMarketplace
//
//  File isolation: imports StreamFeeds + StreamCore only.
//

import Combine
import Foundation
import StreamCore
import StreamFeeds

@MainActor
final class FeedsService: ObservableObject {
    static let shared = FeedsService()

    enum State {
        case idle
        case connecting
        case connected
        case failed(Error)
    }

    @Published private(set) var state: State = .idle
    private(set) var client: FeedsClient?

    /// Cached feed handles. Both the Feed and Profile tabs must observe the *same*
    /// `Feed` (and therefore the same `FeedState`) instance, so that a follow/unfollow
    /// performed on one screen is reflected live on the other. Re-creating the feed
    /// via `client.feed(for:)` on each access would hand out detached state objects.
    private var cachedTimeline: Feed?
    private var cachedUserFeed: Feed?
    private var cachedNotifFeed: Feed?

    private init() {}

    // MARK: - Lifecycle

    func setUp() {
        guard client == nil else { return }
        Task { await connect() }
    }

    func connect() async {
        guard client == nil else { return }
        state = .connecting

        let user = User(
            id: StreamConfig.currentUserId,
            name: StreamConfig.currentUserName,
            imageURL: StreamConfig.currentUserImage,
            role: "user"
        )
        let token = UserToken(rawValue: StreamConfig.feedsUserToken)
        let feedsClient = FeedsClient(
            apiKey: APIKey(StreamConfig.feedsApiKey),
            user: user,
            token: token
        )

        do {
            try await feedsClient.connect()
            client = feedsClient

            // Build the shared feed handles exactly once, after connect.
            cachedTimeline = feedsClient.feed(
                for: FeedQuery(
                    feed: FeedId(group: "timeline", id: feedsClient.user.id),
                    data: .init(
                        members: [.init(userId: feedsClient.user.id)],
                        visibility: .public
                    )
                )
            )
            cachedUserFeed = feedsClient.feed(for: FeedId(group: "user", id: feedsClient.user.id))
            cachedNotifFeed = feedsClient.feed(for: FeedId(group: "notification", id: feedsClient.user.id))

            state = .connected
            await seedFollowGraphIfNeeded(client: feedsClient)
        } catch {
            print("[Feeds] connect failed: \(error.localizedDescription)")
            state = .failed(error)
        }
    }

    func disconnect() async {
        await client?.disconnect()
        client = nil
        cachedTimeline = nil
        cachedUserFeed = nil
        cachedNotifFeed = nil
        state = .idle
    }

    func registerDevice(tokenHex: String) async {
        guard let client else { return }
        do {
            try await client.createDevice(id: tokenHex)
        } catch {
            print("[Feeds] createDevice failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Feed handles (shared, created once in connect)

    func userFeed(userId: String? = nil) -> Feed? {
        // A specific user id always builds a fresh handle (used for browsing peers);
        // the current user's own feed returns the shared cached instance.
        if let userId, userId != client?.user.id {
            return client?.feed(for: FeedId(group: "user", id: userId))
        }
        return cachedUserFeed
    }

    func timelineFeed() -> Feed? { cachedTimeline }

    func notificationFeed() -> Feed? { cachedNotifFeed }

    // MARK: - Follow graph

    /// Follows a peer's user feed from the current user's timeline, then refreshes the
    /// timeline so the newly-followed seller's activities appear immediately. The
    /// `following` list on `FeedState` updates reactively, so the Profile screen's
    /// counts refresh on their own.
    func follow(_ targetUserId: String) async {
        guard let timeline = cachedTimeline else { return }
        do {
            _ = try await timeline.follow(
                FeedId(group: "user", id: targetUserId),
                createNotificationActivity: true
            )
            try await timeline.getOrCreate()
        } catch {
            print("[Feeds] follow failed: \(error.localizedDescription)")
        }
    }

    /// Whether the current user's timeline already follows the given peer. Returns a
    /// plain `Bool` so non-Stream files (Discover / ListingDetail) can drive button state.
    func isFollowing(_ targetUserId: String) -> Bool {
        guard let timeline = cachedTimeline else { return false }
        return timeline.state.following.contains {
            $0.targetFeed.feed.group == "user" && $0.targetFeed.feed.id == targetUserId
        }
    }

    func unfollow(_ targetUserId: String) async {
        guard let timeline = cachedTimeline else { return }
        do {
            _ = try await timeline.unfollow(FeedId(group: "user", id: targetUserId))
            try await timeline.getOrCreate()
        } catch {
            print("[Feeds] unfollow failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Marketplace seeding

    /// Ensures the current user's own feed has a couple of listing posts so their
    /// profile/recommendations aren't empty. We intentionally do NOT auto-follow peers
    /// here: following is a user action (the "Who to follow" list), and the timeline
    /// must start empty so following a seller visibly populates it.
    private func seedFollowGraphIfNeeded(client: FeedsClient) async {
        guard let timeline = cachedTimeline, let userFeed = cachedUserFeed else { return }
        do {
            try await timeline.getOrCreate()
            try await userFeed.getOrCreate()

            // Only seed own listings once (when the user feed has no activities yet).
            guard userFeed.state.activities.isEmpty else { return }

            for listing in MarketplaceRepository.shared.listings
            where listing.sellerId == client.user.id {
                _ = try? await userFeed.addActivity(
                    request: .init(
                        custom: [
                            "listing_id": .string(listing.id),
                            "listing_price": .number(listing.price),
                            "listing_image": .string(listing.imageURL?.absoluteString ?? ""),
                            "listing_category": .string(listing.category.rawValue),
                            "listing_channel_id": .string(listing.channelId ?? ""),
                            "listing_seller_id": .string(listing.sellerId)
                        ],
                        text: "Just listed: \(listing.title) — \(Int(listing.price)) USD. DM if interested!",
                        type: "listing"
                    )
                )
            }
        } catch {
            print("[Feeds] seed own feed failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Heart / favourite an activity

    func heart(activityId: String, in feed: Feed, hasReacted: Bool) async {
        do {
            if hasReacted {
                try await feed.deleteReaction(activityId: activityId, type: "heart")
            } else {
                try await feed.addReaction(
                    activityId: activityId,
                    request: .init(createNotificationActivity: true, type: "heart")
                )
            }
        } catch {
            print("[Feeds] heart toggle failed: \(error.localizedDescription)")
        }
    }
}
