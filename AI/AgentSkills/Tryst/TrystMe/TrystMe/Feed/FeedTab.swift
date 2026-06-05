//
//  FeedTab.swift
//  TrystMe
//
//  ISOLATED Stream Feeds file (StreamFeeds + StreamCore only).
//  Activity timeline, composer, follow recommendations, follow/unfollow, and a
//  notification feed — all built on the headless Feeds SDK state objects.
//

import SwiftUI
import StreamCore
import StreamFeeds

struct FeedTab: View {
    @ObservedObject private var feeds = FeedsService.shared

    var body: some View {
        Group {
            if let client = feeds.client {
                TimelineScreen(client: client)
                    .id(client.user.id) // rebuild feeds when the user switches
            } else {
                ProgressView("Connecting to Feeds…")
            }
        }
    }
}

struct TimelineScreen: View {
    let client: FeedsClient

    @State private var timeline: Feed
    @State private var userFeed: Feed
    @State private var notifications: Feed
    @ObservedObject private var timelineState: FeedState
    @ObservedObject private var notifState: FeedState

    @State private var showComposer = false
    @State private var showNotifications = false
    @State private var showSuggestions = false
    @State private var commentsActivity: ActivityData?

    init(client: FeedsClient) {
        self.client = client
        let tl = client.feed(for: FeedId(group: "timeline", id: client.user.id))
        let uf = client.feed(for: FeedQuery(
            feed: FeedId(group: "user", id: client.user.id),
            data: .init(members: [.init(userId: client.user.id)], visibility: .public)
        ))
        let nf = client.feed(for: FeedId(group: "notification", id: client.user.id))
        _timeline = State(initialValue: tl)
        _userFeed = State(initialValue: uf)
        _notifications = State(initialValue: nf)
        timelineState = tl.state
        notifState = nf.state
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    FollowSuggestionsBar(feed: userFeed, client: client)
                    Divider()

                    if timelineState.activities.isEmpty {
                        emptyState
                    } else {
                        ForEach(timelineState.activities) { activity in
                            ActivityRow(
                                activity: activity,
                                feed: feedForActivity(activity),
                                currentUserId: client.user.id,
                                onComment: { commentsActivity = activity }
                            )
                            Divider()
                            if activity.id == timelineState.activities.last?.id {
                                Color.clear.frame(height: 1).task {
                                    guard timelineState.canLoadMoreActivities else { return }
                                    try? await timeline.queryMoreActivities(limit: 10)
                                }
                            }
                        }
                    }
                }
            }
            .refreshable { await refresh() }
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSuggestions = true } label: { Image(systemName: "person.2.fill") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NotificationBell(state: notifState) { showNotifications = true }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button { showComposer = true } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.title2.bold()).foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(Brand.primaryGradient, in: Circle())
                        .shadow(color: Brand.pink.opacity(0.4), radius: 10, y: 6)
                }
                .padding(20)
            }
            .task { await refresh() }
            .sheet(isPresented: $showComposer) {
                ComposeSheet(feed: userFeed).presentationDetents([.medium])
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsSheet(feed: notifications)
            }
            .sheet(isPresented: $showSuggestions) {
                PeopleToFollowSheet(feed: userFeed, client: client)
            }
            .sheet(item: $commentsActivity) { activity in
                CommentsSheet(activityId: activity.id, feed: feedForActivity(activity), client: client)
                    .presentationDetents([.large])
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles").font(.system(size: 44)).foregroundStyle(Brand.pink)
            Text("Your feed is quiet").font(.headline)
            Text("Follow more people to see their posts here.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(40)
    }

    private func feedForActivity(_ activity: ActivityData) -> Feed {
        // React/comment on the author's user feed.
        client.feed(for: FeedId(group: "user", id: activity.user.id))
    }

    private func refresh() async {
        try? await timeline.getOrCreate()
        try? await userFeed.getOrCreate()
        try? await notifications.getOrCreate()
    }
}

struct NotificationBell: View {
    @ObservedObject var state: FeedState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                if let unread = state.notificationStatus?.unread, unread > 0 {
                    Text("\(unread)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Brand.pink, in: Circle())
                        .offset(x: 9, y: -9)
                }
            }
        }
    }
}
