//
//  ChatService.swift
//  TrystMe
//
//  ISOLATED Stream Chat file. Imports ONLY StreamChat + StreamChatSwiftUI.
//  Never import StreamVideoSwiftUI or StreamCore here — `ViewFactory`,
//  `@Injected`, `User`, and `Token` collide across the SDKs.
//

import Foundation
import StreamChat
import StreamChatSwiftUI

final class ChatService {
    static let shared = ChatService()

    private(set) var streamChat: StreamChat?
    private(set) var client: ChatClient?
    private(set) var currentUserId: String?

    private init() {}

    // MARK: - Lifecycle

    func connect(userId: String, name: String, image: String, token: String) {
        let chatClient = ensureClient()
        currentUserId = userId

        let userInfo = UserInfo(
            id: userId,
            name: name,
            imageURL: URL(string: image)
        )
        let chatToken = Token(stringLiteral: token)

        // If a different user is connected, log out first to avoid state corruption.
        if chatClient.currentUserId != nil, chatClient.currentUserId != userId {
            chatClient.logout { [weak chatClient] in
                chatClient?.connectUser(userInfo: userInfo, token: chatToken) { error in
                    if let error { print("Chat connect error: \(error)") }
                }
            }
        } else {
            chatClient.connectUser(userInfo: userInfo, token: chatToken) { error in
                if let error { print("Chat connect error: \(error)") }
            }
        }
    }

    func disconnect() {
        client?.logout { }
        currentUserId = nil
    }

    /// Register the APNs device token so Stream can deliver chat push alerts.
    func registerDevice(token: Data) {
        client?.currentUserController().addDevice(.apn(token: token)) { error in
            if let error { print("Chat device registration error: \(error)") }
        }
    }

    @discardableResult
    private func ensureClient() -> ChatClient {
        if let client { return client }
        var config = ChatClientConfig(apiKey: .init(Secrets.chatVideoAPIKey))
        config.isLocalStorageEnabled = true
        config.staysConnectedInBackground = true
        let chatClient = ChatClient(config: config)
        client = chatClient
        streamChat = StreamChat(chatClient: chatClient, appearance: ChatAppearance.make())
        return chatClient
    }

    // MARK: - Matches

    /// Deterministic channel id so both sides resolve the same conversation.
    func channelId(with otherId: String) -> ChannelId {
        let me = currentUserId ?? Roster.currentUserId
        let pair = [me, otherId].sorted().joined(separator: "-")
        return ChannelId(type: .custom(Secrets.channelType), id: "match-\(pair)")
    }

    func createMatchChannel(with otherId: String, name: String) {
        guard let client, let me = currentUserId else { return }
        do {
            let controller = try client.channelController(
                createChannelWithId: channelId(with: otherId),
                name: nil,
                imageURL: nil,
                members: [me, otherId],
                extraData: [:]
            )
            controller.synchronize { error in
                if let error { print("Match channel error: \(error)") }
            }
        } catch {
            print("Match channel error: \(error)")
        }
    }

    // MARK: - People search (queries Stream users, maps to plain Profiles)

    func searchProfiles(matching query: String, completion: @escaping ([Profile]) -> Void) {
        guard let client else { completion([]); return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let query: UserListQuery = trimmed.isEmpty
            ? UserListQuery(filter: .exists(.id),
                            sort: [.init(key: .name, isAscending: true)], pageSize: 30)
            : UserListQuery(filter: .autocomplete(.name, text: trimmed),
                            sort: [.init(key: .name, isAscending: true)], pageSize: 30)
        let controller = client.userListController(query: query)
        controller.synchronize { [weak controller] _ in
            let me = self.currentUserId
            let profiles = (controller?.users ?? [])
                .filter { $0.id != me }
                .map { Self.profile(from: $0) }
            DispatchQueue.main.async { completion(profiles) }
        }
    }

    private static func profile(from user: ChatUser) -> Profile {
        let custom = user.extraData
        let id = user.id
        let roster = Roster.profile(id)
        let interests = custom["interests"]?.arrayValue?.compactMap { $0.stringValue }
            ?? roster?.interests ?? []
        return Profile(
            id: id,
            name: user.name ?? roster?.name ?? id,
            age: Int(custom["age"]?.numberValue ?? 0),
            gender: custom["gender"]?.stringValue ?? "",
            lookingFor: custom["looking_for"]?.stringValue ?? "everyone",
            job: custom["job"]?.stringValue ?? "",
            city: custom["city"]?.stringValue ?? "",
            bio: custom["bio"]?.stringValue ?? "",
            interests: interests,
            // Prefer the curated roster portraits so faces stay consistent app-wide.
            photos: roster?.photos ?? Profile.photos(for: id),
            avatarURL: roster?.avatarURL ?? user.imageURL ?? Profile.avatar(for: id)
        )
    }
}
