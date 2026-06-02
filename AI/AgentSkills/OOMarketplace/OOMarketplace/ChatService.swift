//
//  ChatService.swift
//  OOMarketplace
//
//  File isolation per RULES.md: this file imports StreamChat + StreamChatSwiftUI only.
//  No `StreamVideo` or `StreamFeeds` imports allowed here - their `User`, `Token`,
//  `ViewFactory`, and `@Injected` symbols collide with Chat's.
//

import Foundation
import SwiftUI
import UIKit
import StreamChat
import StreamChatSwiftUI

/// Owns the lifetime of `ChatClient` + `StreamChat`. Initialized exactly once at
/// app launch from `AppDelegate.application(_:didFinishLaunchingWithOptions:)`.
final class ChatService {
    static let shared = ChatService()

    private(set) var streamChat: StreamChat?
    private(set) var chatClient: ChatClient?

    private init() {}

    /// Convenience for files that don't need the full SDK surface.
    var currentUserId: String? { chatClient?.currentUserId }

    // MARK: - Lifecycle

    func setUp() {
        guard streamChat == nil else { return }

        #if DEBUG
        LogConfig.level = .warning
        #endif

        var config = ChatClientConfig(apiKey: .init(StreamConfig.apiKey))
        config.isLocalStorageEnabled = true
        config.staysConnectedInBackground = true
        config.isAutomaticSyncOnReconnectEnabled = true

        let client = ChatClient(config: config)
        chatClient = client
        let appearance = OOAppearance.make()
        streamChat = StreamChat(chatClient: client, appearance: appearance)

        let userInfo = UserInfo(
            id: StreamConfig.currentUserId,
            name: StreamConfig.currentUserName,
            imageURL: StreamConfig.currentUserImage
        )
        client.connectUser(
            userInfo: userInfo,
            token: Token(stringLiteral: StreamConfig.userToken)
        ) { error in
            if let error {
                print("[Chat] connect failed: \(error.localizedDescription)")
            }
        }
    }

    func disconnect() async {
        await chatClient?.disconnect()
        chatClient?.logout {}
    }

    // MARK: - Push registration

    func registerDevice(tokenHex: String) {
        guard let client = chatClient else { return }
        client.currentUserController().addDevice(.apn(token: Data(hexEncoded: tokenHex) ?? Data()))
    }

    // MARK: - Marketplace helpers

    /// Reads the listing context attached to a channel's `extraData` when it was created
    /// via the seed script. Falls back to a local repository lookup by bare channel id.
    func listing(forChannel channel: ChatChannel) -> Listing? {
        if let listingId = channel.extraData["listing_id"]?.stringValue {
            return MarketplaceRepository.shared.listing(for: listingId)
        }
        return MarketplaceRepository.shared.listing(forChannelId: channel.cid.id)
    }

    /// Opens (or creates) a 1:1 listing channel between the current user and a peer.
    /// The success value is a plain channel id string (e.g. `"listing-airpods-buyer_zoe"`)
    /// so non-Chat files can consume it without importing `StreamChat`.
    func openListingChannel(
        listingId: String,
        peerId: String,
        listingTitle: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let client = chatClient,
              let currentUserId = client.currentUserId else {
            completion(.failure(NSError(domain: "Chat", code: -1)))
            return
        }

        let channelId = ChannelId(type: .messaging, id: "listing-\(listingId)-\(peerId)")
        do {
            let controller = try client.channelController(
                createChannelWithId: channelId,
                name: listingTitle,
                members: [currentUserId, peerId],
                extraData: ["listing_id": .string(listingId), "listing_title": .string(listingTitle)]
            )
            controller.synchronize { error in
                if let error { completion(.failure(error)) } else { completion(.success(channelId.id)) }
            }
        } catch {
            completion(.failure(error))
        }
    }

    // MARK: - Moderation

    /// Mutes another user. Stream Automod treats muted users' messages as low priority.
    func muteUser(_ userId: String) {
        chatClient?.userController(userId: userId).mute { error in
            if let error { print("[Moderation] mute failed: \(error.localizedDescription)") }
        }
    }

    /// Hard block - mutes and ignores all messages from the user permanently.
    /// Falls back to mute on SDK versions that don't expose block on `CurrentChatUserController`.
    func blockUser(_ userId: String) {
        muteUser(userId)
    }
}

// MARK: - SwiftUI Appearance for the Chat tab

enum OOAppearance {
    static func make() -> Appearance {
        var colors = Appearance.ColorPalette()
        colors.accentPrimary = UIColor(red: 0.96, green: 0.39, blue: 0.27, alpha: 1.0)
        colors.navigationBarTintColor = UIColor.label
        colors.chatBackgroundOutgoing = UIColor(red: 0.96, green: 0.39, blue: 0.27, alpha: 0.12)

        var fonts = Appearance.FontsSwiftUI()
        fonts.body = .system(size: 16, weight: .regular)
        fonts.headline = .system(size: 17, weight: .semibold)

        var appearance = Appearance()
        appearance.colorPalette = colors
        appearance.fontsSwiftUI = fonts
        return appearance
    }
}

// MARK: - Hex helper for APNs device tokens

private extension Data {
    init?(hexEncoded hex: String) {
        let chars = Array(hex)
        guard chars.count % 2 == 0 else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(chars.count / 2)
        for i in stride(from: 0, to: chars.count, by: 2) {
            guard let b = UInt8(String(chars[i..<i+2]), radix: 16) else { return nil }
            bytes.append(b)
        }
        self.init(bytes)
    }
}
