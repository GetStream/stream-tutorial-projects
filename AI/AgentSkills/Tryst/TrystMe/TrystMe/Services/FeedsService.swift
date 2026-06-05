//
//  FeedsService.swift
//  TrystMe
//
//  ISOLATED Stream Feeds file. Imports ONLY StreamFeeds + StreamCore.
//  StreamCore's `User`/`UserToken`/`APIKey` collide with StreamVideo's types,
//  so keep all Feeds construction here.
//

import Foundation
import Combine
import StreamCore
import StreamFeeds

@MainActor
final class FeedsService: ObservableObject {
    static let shared = FeedsService()

    @Published private(set) var client: FeedsClient?
    @Published private(set) var isConnected = false

    private var deviceToken: String?

    private init() {}

    func connect(userId: String, name: String, image: String, token: String) async {
        if client != nil { await disconnect() }
        let user = User(id: userId, name: name, imageURL: URL(string: image), role: "user")
        let feedsClient = FeedsClient(
            apiKey: APIKey(Secrets.feedsAPIKey),
            user: user,
            token: UserToken(rawValue: token)
        )
        do {
            try await feedsClient.connect()
            client = feedsClient
            isConnected = true
            if let deviceToken { try? await feedsClient.createDevice(id: deviceToken) }
        } catch {
            print("Feeds connect error: \(error)")
            isConnected = false
        }
    }

    func disconnect() async {
        guard let client else { return }
        await client.disconnect()
        self.client = nil
        isConnected = false
    }

    func registerDevice(token: String) {
        deviceToken = token
        guard let client else { return }
        Task { try? await client.createDevice(id: token) }
    }

    // MARK: - Feed factories

    func timelineFeed() -> Feed? {
        guard let client else { return nil }
        return client.feed(for: FeedId(group: "timeline", id: client.user.id))
    }

    func userFeed(for userId: String? = nil) -> Feed? {
        guard let client else { return nil }
        return client.feed(for: FeedId(group: "user", id: userId ?? client.user.id))
    }

    func notificationFeed() -> Feed? {
        guard let client else { return nil }
        return client.feed(for: FeedId(group: "notification", id: client.user.id))
    }

    // MARK: - Cross-feature intents (called from neutral AppModel)

    /// Best-effort "like" alert into the target's notification feed.
    nonisolated func sendLikeNotification(to userId: String) {
        Task { @MainActor in
            guard let client else { return }
            let me = client.user.name ?? client.user.id
            let feed = client.feed(for: FeedId(group: "notification", id: userId))
            try? await feed.addActivity(
                request: .init(
                    custom: ["kind": .string("like")],
                    text: "\(me) liked your profile ❤️",
                    type: "like"
                )
            )
        }
    }
}
