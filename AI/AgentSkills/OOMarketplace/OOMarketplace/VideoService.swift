//
//  VideoService.swift
//  OOMarketplace
//
//  File isolation per RULES.md: this file imports StreamVideo + StreamVideoSwiftUI only.
//  No StreamChat / StreamFeeds imports - their `User`/`Token`/`ViewFactory`/`@Injected`
//  symbols would collide.
//

import Foundation
import StreamVideo
import StreamVideoSwiftUI

final class VideoService {
    static let shared = VideoService()

    private(set) var streamVideo: StreamVideo?
    private var streamVideoUI: StreamVideoUI?

    private init() {}

    // MARK: - Lifecycle

    func setUp() {
        guard streamVideo == nil else { return }

        #if DEBUG
        LogConfig.level = .warning
        #endif

        let user = User(
            id: StreamConfig.currentUserId,
            name: StreamConfig.currentUserName,
            imageURL: StreamConfig.currentUserImage,
            customData: [:]
        )
        let token = UserToken(rawValue: StreamConfig.userToken)
        let client = StreamVideo(
            apiKey: StreamConfig.apiKey,
            user: user,
            token: token
        )
        streamVideo = client
        streamVideoUI = StreamVideoUI(streamVideo: client)
    }

    func disconnect() async {
        await streamVideo?.disconnect()
    }

    // MARK: - Push (VoIP / APNs)

    func registerDevice(tokenHex: String) {
        guard let client = streamVideo else { return }
        Task {
            do {
                try await client.setDevice(id: tokenHex)
            } catch {
                print("[Video] setDevice failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Convenience for the call UI

    /// Builds a `Member` list from plain user IDs - keeps `StartCallRequest` SDK-free
    /// so any view can post the notification without importing `StreamVideo`.
    static func members(from userIds: [String]) -> [Member] {
        userIds.map { Member(userId: $0) }
    }
}
