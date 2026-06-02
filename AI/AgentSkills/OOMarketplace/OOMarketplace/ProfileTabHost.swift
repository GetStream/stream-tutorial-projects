//
//  ProfileTabHost.swift
//  OOMarketplace
//
//  File isolation: imports StreamFeeds + StreamCore. Drives the follow graph
//  (following / followers / suggestions), notification feed, and reports.
//

import SwiftUI
import StreamCore
import StreamFeeds

struct ProfileTabHost: View {
    @StateObject private var service = FeedsService.shared

    var body: some View {
        NavigationStack {
            content.navigationTitle("Profile")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch service.state {
        case .idle, .connecting:
            ProgressView().task { await service.connect() }
        case .failed:
            ContentUnavailableView("Couldn't load profile",
                                    systemImage: "person.crop.circle.badge.exclamationmark")
        case .connected:
            if let client = service.client,
               let userFeed = service.userFeed(),
               let timeline = service.timelineFeed(),
               let notifFeed = service.notificationFeed() {
                ProfileView(
                    client: client,
                    userFeed: userFeed,
                    timeline: timeline,
                    notifFeed: notifFeed
                )
            }
        }
    }
}

// MARK: - Profile

struct ProfileView: View {
    let client: FeedsClient
    let userFeed: Feed
    let timeline: Feed
    let notifFeed: Feed

    @ObservedObject var timelineState: FeedState
    @ObservedObject var notifState: FeedState
    @State private var suggestions: [DemoUser] = []
    @State private var showNotifications = false

    init(client: FeedsClient, userFeed: Feed, timeline: Feed, notifFeed: Feed) {
        self.client = client
        self.userFeed = userFeed
        self.timeline = timeline
        self.notifFeed = notifFeed
        timelineState = timeline.state
        notifState = notifFeed.state
    }

    var body: some View {
        List {
            Section { header }

            Section("Notifications") {
                Button {
                    showNotifications = true
                } label: {
                    HStack {
                        Image(systemName: "bell.fill").foregroundStyle(.orange)
                        Text("Marketplace alerts")
                        Spacer()
                        if let unread = notifState.notificationStatus?.unread, unread > 0 {
                            Text("\(unread)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Color.ooAccent, in: Capsule())
                        }
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }

            Section("Following (\(timelineState.following.count))") {
                if timelineState.following.isEmpty {
                    Text("You're not following anyone yet. Pick someone below to populate your feed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(timelineState.following, id: \.targetFeed.feed.rawValue) { follow in
                        let peerId = follow.targetFeed.feed.id
                        followRow(name: displayName(forFeedId: peerId, fallback: follow.targetFeed.createdBy.name),
                                  imageURL: avatar(forFeedId: peerId, fallback: follow.targetFeed.createdBy.imageURL),
                                  trailing: "Unfollow") {
                            Task {
                                await FeedsService.shared.unfollow(peerId)
                                refreshSuggestions()
                            }
                        }
                    }
                }
            }

            Section("Followers (\(timelineState.followers.count))") {
                if timelineState.followers.isEmpty {
                    Text("No followers yet.").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(timelineState.followers, id: \.sourceFeed.feed.rawValue) { follower in
                        followRow(name: follower.sourceFeed.createdBy.name ?? follower.sourceFeed.feed.id,
                                  imageURL: follower.sourceFeed.createdBy.imageURL,
                                  trailing: nil) {}
                    }
                }
            }

            Section("Who to follow") {
                ForEach(suggestions) { suggestion in
                    followRow(name: suggestion.name,
                              imageURL: suggestion.imageURL,
                              trailing: "Follow") {
                        Task {
                            await FeedsService.shared.follow(suggestion.id)
                            refreshSuggestions()
                        }
                    }
                }
                if suggestions.isEmpty {
                    Text("You're following everyone we suggested. Check back later.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Safety") {
                Label("Stream Moderation is on", systemImage: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                Text("Chat messages run through Automod. Calls inherit the same user blocklist. Report any seller via the menu on their listing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            try? await timeline.getOrCreate()
            try? await userFeed.getOrCreate()
            try? await notifFeed.getOrCreate()
            refreshSuggestions()
        }
        .onChange(of: timelineState.following.count) { _, _ in
            refreshSuggestions()
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsSheet(notifFeed: notifFeed)
        }
    }

    // MARK: - Helpers

    private var header: some View {
        HStack(spacing: 16) {
            AsyncImage(url: StreamConfig.currentUserImage) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default:                Circle().fill(Color.ooSurface)
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(StreamConfig.currentUserName).font(.title3.bold())
                Text("@" + StreamConfig.currentUserId)
                    .font(.caption).foregroundStyle(.secondary)
                Text("Top-rated • 4.9★ across 132 sales")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func followRow(
        name: String,
        imageURL: URL?,
        trailing: String?,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default:                Circle().fill(Color.ooSurface)
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())

            Text(name).font(.subheadline)
            Spacer()
            if let trailing {
                Button(trailing, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(trailing == "Follow" ? Color.ooAccent : .secondary)
            }
        }
    }

    /// Suggestions are the demo marketplace peers the current user is not already
    /// following. Using the known peer list keeps the "Who to follow" list deterministic
    /// and always populated, instead of depending on server-side follow ranking which
    /// can be empty on a fresh app.
    private func refreshSuggestions() {
        let followingIds = Set(timelineState.following.map { $0.targetFeed.feed.id })
        suggestions = StreamConfig.knownPeers.filter {
            $0.id != StreamConfig.currentUserId && !followingIds.contains($0.id)
        }
    }

    private func displayName(forFeedId id: String, fallback: String?) -> String {
        StreamConfig.knownPeers.first(where: { $0.id == id })?.name ?? fallback ?? id
    }

    private func avatar(forFeedId id: String, fallback: URL?) -> URL? {
        StreamConfig.knownPeers.first(where: { $0.id == id })?.imageURL ?? fallback
    }
}

// MARK: - Notifications sheet

private struct NotificationsSheet: View {
    let notifFeed: Feed
    @ObservedObject var state: FeedState
    @Environment(\.dismiss) private var dismiss

    init(notifFeed: Feed) {
        self.notifFeed = notifFeed
        state = notifFeed.state
    }

    var body: some View {
        NavigationStack {
            List {
                if let status = state.notificationStatus, status.unread > 0 {
                    Button("Mark all as read") {
                        Task { try? await notifFeed.markActivity(request: .init(markAllRead: true)) }
                    }
                    .frame(maxWidth: .infinity)
                }

                ForEach(state.aggregatedActivities, id: \.id) { aggregated in
                    AggregatedActivityRow(
                        aggregated: aggregated,
                        humanText: humanText(for: aggregated),
                        isRead: isRead(aggregated.id),
                        onTap: {
                            Task {
                                try? await notifFeed.markActivity(
                                    request: .init(markRead: [aggregated.id])
                                )
                            }
                        }
                    )
                }

                if state.aggregatedActivities.isEmpty {
                    Text("No new notifications.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { try? await notifFeed.getOrCreate() }
        }
    }

    private func isRead(_ id: String) -> Bool {
        state.notificationStatus?.readActivities.contains(id) == true
    }

    private func humanText(for aggregated: AggregatedActivityData) -> String { humanTextHelper(aggregated) }
}

private struct AggregatedActivityRow: View {
    let aggregated: AggregatedActivityData
    let humanText: String
    let isRead: Bool
    let onTap: () -> Void

    var body: some View {
        let avatar = aggregated.activities.first?.user.imageURL
        let date = aggregated.activities.first?.createdAt

        return HStack(spacing: 12) {
            AsyncImage(url: avatar) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default:                Circle().fill(Color.ooSurface)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            VStack(alignment: .leading) {
                Text(humanText).font(.subheadline)
                if let date {
                    Text(date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !isRead {
                Circle().fill(Color.ooAccent).frame(width: 8, height: 8)
            }
        }
        .listRowBackground(isRead ? Color.clear : Color.ooAccent.opacity(0.06))
        .onTapGesture(perform: onTap)
    }
}

private func humanTextHelper(_ aggregated: AggregatedActivityData) -> String {
    let firstNames = aggregated.activities.prefix(2)
        .map { $0.user.name ?? $0.user.id }
        .joined(separator: " and ")
    let extra = aggregated.userCount > 2 ? " and \(aggregated.userCount - 2) others" : ""
    let action: String
    switch aggregated.group {
    case "react":    action = "hearted your listing"
    case "comment":  action = "commented on your listing"
    case "follow":   action = "followed you"
    default:         action = "interacted with your post"
    }
    return "\(firstNames)\(extra) \(action)"
}
