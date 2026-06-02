//
//  FeedTabHost.swift
//  OOMarketplace
//
//  File isolation: imports StreamFeeds + StreamCore. Never import StreamChat or
//  StreamVideo here.
//

import SwiftUI
import StreamCore
import StreamFeeds

// MARK: - Tab host

struct FeedTabHost: View {
    @StateObject private var service = FeedsService.shared

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Marketplace Feed")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch service.state {
        case .idle, .connecting:
            ProgressView("Connecting to Stream Feeds…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { await service.connect() }

        case .failed(let error):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle).foregroundStyle(.orange)
                Text("Feed unavailable").font(.headline)
                Text(error.localizedDescription)
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") { Task { await service.connect() } }
                    .buttonStyle(.borderedProminent)
            }
            .padding()

        case .connected:
            if let client = service.client,
               let timeline = service.timelineFeed(),
               let userFeed = service.userFeed() {
                MarketplaceTimelineView(client: client, timeline: timeline, userFeed: userFeed)
            } else {
                ProgressView()
            }
        }
    }
}

// MARK: - Timeline

struct MarketplaceTimelineView: View {
    let client: FeedsClient
    let timeline: Feed
    let userFeed: Feed

    @ObservedObject var timelineState: FeedState
    @ObservedObject var userState: FeedState

    @State private var showComposer = false

    init(client: FeedsClient, timeline: Feed, userFeed: Feed) {
        self.client = client
        self.timeline = timeline
        self.userFeed = userFeed
        timelineState = timeline.state
        userState = userFeed.state
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                RecommendationsStrip(timelineState: timelineState, timeline: timeline)
                    .padding(.bottom, 4)
                Divider()

                ForEach(timelineState.activities) { activity in
                    ActivityRowView(
                        activity: activity,
                        feed: timeline
                    )
                    Divider()

                    if activity.id == timelineState.activities.last?.id {
                        Color.clear.frame(height: 1)
                            .task {
                                guard timelineState.canLoadMoreActivities else { return }
                                try? await timeline.queryMoreActivities(limit: 10)
                            }
                    }
                }

                if timelineState.activities.isEmpty {
                    EmptyTimelineView { showComposer = true }
                        .padding(.top, 60)
                }
            }
        }
        .refreshable {
            try? await timeline.getOrCreate()
            try? await userFeed.getOrCreate()
        }
        .task {
            try? await timeline.getOrCreate()
            try? await userFeed.getOrCreate()
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                showComposer = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.ooAccent, in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
            }
            .padding(20)
        }
        .sheet(isPresented: $showComposer) {
            ListingActivityComposer(feed: userFeed)
                .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Empty timeline

private struct EmptyTimelineView: View {
    let onCompose: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No activity from people you follow yet")
                .font(.headline)
            Text("Follow sellers on the Profile tab to see their listings here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Post your first listing") { onCompose() }
                .buttonStyle(.borderedProminent)
                .tint(Color.ooAccent)
        }
        .padding()
    }
}

// MARK: - Recommendations strip

struct RecommendationsStrip: View {
    @ObservedObject var timelineState: FeedState
    let timeline: Feed

    /// Naïve "for you" picks: the most recent listing activity per author the user
    /// already follows. Stream Feeds ranking can replace this with a server-side rule.
    private var recommendations: [ActivityData] {
        var byAuthor: [String: ActivityData] = [:]
        for activity in timelineState.activities where activity.type == "listing" {
            if byAuthor[activity.user.id] == nil { byAuthor[activity.user.id] = activity }
        }
        return Array(byAuthor.values.prefix(8))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("For you", systemImage: "sparkles")
                    .font(.subheadline.bold())
                Spacer()
                Text("Powered by Stream Feeds")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    if recommendations.isEmpty {
                        ForEach(0..<3, id: \.self) { _ in
                            RecommendationPlaceholder()
                                .frame(width: 180)
                        }
                    } else {
                        ForEach(recommendations) { activity in
                            RecommendationCard(activity: activity, feed: timeline)
                                .frame(width: 180)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 10)
    }
}

/// Resolves a bundled asset name for a feed activity by matching its `listing_image`
/// URL against the local catalog (ignoring query params). Lets feed posts reuse the
/// reliable bundled photos instead of depending on a flaky remote fetch.
func listingAssetName(forImage imageString: String?) -> String? {
    guard let imageString, let path = URL(string: imageString)?.path else { return nil }
    return MarketplaceRepository.shared.listings.first { $0.imageURL?.path == path }?.id
}

private struct RecommendationCard: View {
    let activity: ActivityData
    let feed: Feed

    private var imageURL: URL? {
        URL(string: activity.custom["listing_image"]?.stringValue ?? "")
    }
    private var assetName: String? {
        listingAssetName(forImage: activity.custom["listing_image"]?.stringValue)
    }
    private var price: Int? {
        activity.custom["listing_price"]?.numberValue.map(Int.init)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProductImage(assetName: assetName, url: imageURL) {
                Color.ooSurface
            }
            .frame(height: 110)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(activity.text ?? "")
                .font(.caption.bold())
                .lineLimit(2)

            HStack {
                if let price { Text("$\(price)").font(.caption.bold()).foregroundStyle(Color.ooAccent) }
                Spacer()
                Text("@" + (activity.user.name ?? activity.user.id))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct RecommendationPlaceholder: View {
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 12).fill(Color.ooSurface).frame(height: 110)
            Text("Tap Follow on a seller to see their items here.")
                .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
        }
        .padding(8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Activity row

struct ActivityRowView: View {
    let activity: ActivityData
    let feed: Feed

    private var hasLiked: Bool {
        !activity.ownReactions.filter { $0.type == "heart" }.isEmpty
    }
    private var heartCount: Int { activity.reactionGroups["heart"]?.count ?? 0 }
    private var price: Int? { activity.custom["listing_price"]?.numberValue.map(Int.init) }
    private var image: URL? { URL(string: activity.custom["listing_image"]?.stringValue ?? "") }
    private var assetName: String? { listingAssetName(forImage: activity.custom["listing_image"]?.stringValue) }
    private var channelId: String? { activity.custom["listing_channel_id"]?.stringValue }
    private var sellerId: String? { activity.custom["listing_seller_id"]?.stringValue }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                AsyncImage(url: activity.user.imageURL) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default:                  Circle().fill(Color.ooSurface)
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.user.name ?? activity.user.id).font(.subheadline.bold())
                    Text(activity.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Menu {
                    Button("Mute author", systemImage: "speaker.slash") {}
                    Button("Report", systemImage: "flag", role: .destructive) {
                        NotificationCenter.default.post(
                            name: AppEvents.reportUser,
                            object: ReportUserRequest(
                                userId: activity.user.id,
                                reason: "Reported via feed",
                                context: "feed"
                            )
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis").foregroundStyle(.secondary)
                }
            }

            if let text = activity.text { Text(text).font(.body) }

            if image != nil || assetName != nil {
                ProductImage(assetName: assetName, url: image) {
                    Color.ooSurface
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if let price {
                Label("$\(price)", systemImage: "tag.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.ooAccent)
            }

            HStack(spacing: 20) {
                Button {
                    Task { await FeedsService.shared.heart(activityId: activity.id, in: feed, hasReacted: hasLiked) }
                } label: {
                    Label("\(heartCount)", systemImage: hasLiked ? "heart.fill" : "heart")
                        .foregroundStyle(hasLiked ? Color.ooAccent : .secondary)
                }

                Button {
                    Task { try? await feed.repost(activityId: activity.id, text: nil) }
                } label: {
                    Label("\(activity.shareCount)", systemImage: "arrowshape.turn.up.right")
                }

                if let channelId {
                    Button {
                        NotificationCenter.default.post(
                            name: AppEvents.openChat,
                            object: OpenChatRequest(channelId: channelId, listingTitle: activity.text)
                        )
                    } label: {
                        Label("Message", systemImage: "bubble.left")
                    }
                }

                if let sellerId, sellerId != StreamConfig.currentUserId {
                    Button {
                        NotificationCenter.default.post(
                            name: AppEvents.startCall,
                            object: StartCallRequest(
                                calleeId: sellerId,
                                calleeName: activity.user.name ?? sellerId,
                                audioOnly: false,
                                listingTitle: activity.text
                            )
                        )
                    } label: {
                        Label("Video", systemImage: "video")
                    }
                }
                Spacer()
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .padding()
    }
}

// MARK: - Composer

struct ListingActivityComposer: View {
    let feed: Feed
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var asStory = false
    @State private var isPosting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("What are you selling or sharing?") {
                    TextField("Describe your listing…", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section {
                    Toggle("Post as Story (expires in 24h)", isOn: $asStory)
                }
            }
            .navigationTitle("New post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { Task { await post() } }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
                }
            }
        }
    }

    private func post() async {
        isPosting = true
        var expiresAt: String? = nil
        if asStory {
            expiresAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(24 * 3600))
        }
        _ = try? await feed.addActivity(
            request: .init(
                expiresAt: expiresAt,
                text: text,
                type: "post"
            )
        )
        isPosting = false
        dismiss()
    }
}
