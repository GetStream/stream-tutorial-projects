//
//  VideoService.swift
//  TrystMe
//
//  ISOLATED Stream Video file. Imports ONLY StreamVideo + StreamVideoSwiftUI.
//  `User`/`UserToken` here collide with StreamChat's `Token` and StreamCore's
//  `User`, so this construction must live alone.
//

import Foundation
import StreamVideo
import StreamVideoSwiftUI

final class VideoService {
    static let shared = VideoService()

    private(set) var streamVideo: StreamVideo?
    private var streamVideoUI: StreamVideoUI?   // must stay alive; not exposed

    private init() {}

    func connect(userId: String, name: String, image: String, token: String) {
        // Recreate the client when switching users (demo profile switching).
        if streamVideo != nil {
            disconnect()
        }
        let user = User(
            id: userId,
            name: name,
            imageURL: URL(string: image),
            customData: [:]
        )
        let videoToken = UserToken(rawValue: token)
        let client = StreamVideo(apiKey: Secrets.chatVideoAPIKey, user: user, token: videoToken)
        streamVideo = client
        streamVideoUI = StreamVideoUI(streamVideo: client)
    }

    func disconnect() {
        Task { await streamVideo?.disconnect() }
        streamVideo = nil
        streamVideoUI = nil
    }

    /// Build call members from plain user ids (used by the call layer).
    func members(for userIds: [String]) -> [Member] {
        userIds.map { Member(userId: $0) }
    }
}
