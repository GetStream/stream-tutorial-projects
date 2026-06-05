//
//  FeedComponents.swift
//  TrystMe
//
//  ISOLATED Stream Feeds file (StreamFeeds + StreamCore only).
//  Activity rows, follow recommendations, composer, follow graph, notifications.
//

import SwiftUI
import StreamCore
import StreamFeeds

// MARK: - Activity row

struct ActivityRow: View {
    let activity: ActivityData
    let feed: Feed
    let currentUserId: String
    let onComment: () -> Void

    private var hasLiked: Bool { !activity.ownReactions.filter { $0.type == "heart" }.isEmpty }
    private var likeCount: Int { activity.reactionGroups["heart"]?.count ?? 0 }
    private var isBookmarked: Bool { !activity.ownBookmarks.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                AsyncImage(url: activity.user.imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: { Circle().fill(.gray.opacity(0.2)) }
                .frame(width: 44, height: 44).clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(activity.user.name ?? activity.user.id).font(.headline)
                        Spacer()
                        Text(activity.createdAt, style: .relative)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let text = activity.text, !text.isEmpty {
                        Text(text).font(.body)
                    }
                }
            }

            HStack(spacing: 28) {
                Button(action: onComment) {
                    Label("\(activity.commentCount)", systemImage: "bubble.right")
                }
                Button {
                    Task {
                        if hasLiked {
                            try? await feed.deleteReaction(activityId: activity.id, type: "heart")
                        } else {
                            try? await feed.addReaction(
                                activityId: activity.id,
                                request: .init(createNotificationActivity: true, type: "heart")
                            )
                        }
                    }
                } label: {
                    Label("\(likeCount)", systemImage: hasLiked ? "heart.fill" : "heart")
                        .foregroundStyle(hasLiked ? Brand.pink : .secondary)
                }
                Button {
                    Task { try? await feed.repost(activityId: activity.id, text: nil) }
                } label: {
                    Label("\(activity.shareCount)", systemImage: "arrow.2.squarepath")
                }
                Spacer()
                Button {
                    Task {
                        if isBookmarked {
                            try? await feed.deleteBookmark(activityId: activity.id)
                        } else {
                            try? await feed.addBookmark(activityId: activity.id)
                        }
                    }
                } label: {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(isBookmarked ? Brand.purple : .secondary)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
            .padding(.leading, 56)
        }
        .padding(16)
    }
}

// MARK: - Follow suggestions (horizontal "who to follow")

struct FollowSuggestionsBar: View {
    let feed: Feed
    let client: FeedsClient

    @State private var suggestions: [FeedData] = []
    @State private var selectedProfile: Profile?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !suggestions.isEmpty {
                Text("Recommended for you")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 16).padding(.top, 12)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(suggestions, id: \.feed.rawValue) { suggestion in
                            suggestionCard(suggestion)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 8)
                }
            }
        }
        .task { await load() }
        .sheet(item: $selectedProfile) { ProfileDetailView(profile: $0) }
    }

    private func suggestionCard(_ suggestion: FeedData) -> some View {
        VStack(spacing: 8) {
            // Tapping the avatar/name opens the full profile.
            Button {
                selectedProfile = Self.profile(from: suggestion)
            } label: {
                VStack(spacing: 8) {
                    AsyncImage(url: suggestion.createdBy.imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: { Circle().fill(.gray.opacity(0.2)) }
                    .frame(width: 64, height: 64).clipShape(Circle())

                    Text(suggestion.createdBy.name ?? suggestion.feed.id)
                        .font(.caption.bold()).lineLimit(1)
                        .foregroundStyle(.primary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button("Follow") {
                Task {
                    try? await feed.follow(suggestion.feed, createNotificationActivity: true)
                    suggestions.removeAll { $0.feed.rawValue == suggestion.feed.rawValue }
                }
            }
            .font(.caption.bold())
            .padding(.horizontal, 16).padding(.vertical, 6)
            .background(Brand.primaryGradient, in: Capsule())
            .foregroundStyle(.white)
        }
        .frame(width: 110)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    /// Map a suggested user feed to a neutral Profile (roster first, then feed data).
    static func profile(from suggestion: FeedData) -> Profile {
        let id = suggestion.createdBy.id
        if let roster = Roster.profile(id) { return roster }
        return Profile(
            id: id,
            name: suggestion.createdBy.name ?? id,
            age: 0, gender: "", lookingFor: "everyone", job: "", city: "",
            bio: "", interests: [],
            photos: Profile.photos(for: id),
            avatarURL: suggestion.createdBy.imageURL ?? Profile.avatar(for: id)
        )
    }

    private func load() async {
        suggestions = (try? await feed.queryFollowSuggestions(limit: 10)) ?? []
    }
}

// MARK: - Composer

struct ComposeSheet: View {
    let feed: Feed

    @State private var text = ""
    @State private var isPosting = false
    @State private var asStory = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextEditor(text: $text)
                    .frame(minHeight: 120)
                    .padding(8)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.3)))
                Toggle("Post as story (expires in 24h)", isOn: $asStory)
                Spacer()
            }
            .padding()
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { Task { await post() } }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
                }
            }
            .overlay { if isPosting { ProgressView() } }
        }
    }

    private func post() async {
        isPosting = true
        var expiresAt: String?
        if asStory {
            expiresAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(24 * 3600))
        }
        try? await feed.addActivity(request: .init(expiresAt: expiresAt, text: text, type: "post"))
        isPosting = false
        dismiss()
    }
}

// MARK: - Follow graph

struct PeopleToFollowSheet: View {
    let feed: Feed
    let client: FeedsClient

    @ObservedObject private var state: FeedState
    @State private var suggestions: [FeedData] = []

    init(feed: Feed, client: FeedsClient) {
        self.feed = feed
        self.client = client
        state = feed.state
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Following (\(state.following.count))") {
                    ForEach(state.following, id: \.targetFeed.feed.rawValue) { follow in
                        HStack {
                            Text(follow.targetFeed.createdBy.name ?? follow.targetFeed.feed.id)
                            Spacer()
                            Button("Unfollow") {
                                Task { try? await feed.unfollow(follow.targetFeed.feed) }
                            }
                            .buttonStyle(.bordered).controlSize(.small).tint(.secondary)
                        }
                    }
                }
                Section("Followers (\(state.followers.count))") {
                    ForEach(state.followers, id: \.sourceFeed.feed.rawValue) { follower in
                        Text(follower.sourceFeed.createdBy.name ?? follower.sourceFeed.feed.id)
                    }
                }
                if !suggestions.isEmpty {
                    Section("Who to follow") {
                        ForEach(suggestions, id: \.feed.rawValue) { suggestion in
                            HStack {
                                AsyncImage(url: suggestion.createdBy.imageURL) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: { Circle().fill(.gray.opacity(0.2)) }
                                .frame(width: 36, height: 36).clipShape(Circle())
                                Text(suggestion.createdBy.name ?? suggestion.feed.id)
                                Spacer()
                                Button("Follow") {
                                    Task {
                                        try? await feed.follow(suggestion.feed, createNotificationActivity: true)
                                        suggestions.removeAll { $0.feed.rawValue == suggestion.feed.rawValue }
                                    }
                                }
                                .buttonStyle(.borderedProminent).controlSize(.small).tint(Brand.pink)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Connections")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                try? await feed.getOrCreate()
                suggestions = (try? await feed.queryFollowSuggestions(limit: 12)) ?? []
            }
        }
    }
}

// MARK: - Notifications

struct NotificationsSheet: View {
    let feed: Feed
    @ObservedObject private var state: FeedState

    init(feed: Feed) {
        self.feed = feed
        state = feed.state
    }

    var body: some View {
        NavigationStack {
            Group {
                if state.aggregatedActivities.isEmpty {
                    ContentUnavailableView(
                        "No notifications yet",
                        systemImage: "bell.slash",
                        description: Text("Likes, comments and new followers will show up here.")
                    )
                } else {
                    List {
                        if let status = state.notificationStatus, status.unread > 0 {
                            Button("Mark all as read") {
                                Task { try? await feed.markActivity(request: .init(markAllRead: true)) }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        ForEach(state.aggregatedActivities, id: \.id) { aggregated in
                            HStack(spacing: 12) {
                                if let first = aggregated.activities.first {
                                    AsyncImage(url: first.user.imageURL) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: { Circle().fill(.gray.opacity(0.2)) }
                                    .frame(width: 40, height: 40).clipShape(Circle())
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(aggregated.displayText).font(.subheadline)
                                    if let date = aggregated.activities.first?.createdAt {
                                        Text(date, style: .relative).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .task { try? await feed.getOrCreate() }
        }
    }
}

extension AggregatedActivityData {
    var displayText: String {
        let names = activities.prefix(2).map { $0.user.name ?? $0.user.id }.joined(separator: " and ")
        let extra = userCount > 2 ? " and \(userCount - 2) others" : ""
        switch activities.first?.type {
        case "like", "reaction", "react": return "\(names)\(extra) liked your post ❤️"
        case "comment": return "\(names)\(extra) commented on your post"
        case "follow": return "\(names)\(extra) started following you"
        default: return "\(names)\(extra) interacted with you"
        }
    }
}
