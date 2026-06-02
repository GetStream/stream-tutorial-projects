//
//  ListingDetailView.swift
//  OOMarketplace
//
//  No Stream imports. Communicates with chat / video via AppEvents notifications.
//

import SwiftUI

struct ListingDetailView: View {
    let listing: Listing
    @Environment(\.dismiss) private var dismiss
    @StateObject private var repo = MarketplaceRepository.shared
    @State private var isFollowingSeller = false

    private var isOwnListing: Bool { listing.sellerId == StreamConfig.currentUserId }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ProductImage(assetName: listing.id, url: listing.imageURL) {
                        Color.ooSurface
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipped()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(listing.title).font(.title2.bold())
                            Spacer()
                            Button {
                                repo.toggleFavorite(listing.id)
                            } label: {
                                Image(systemName: repo.isFavorite(listing.id) ? "heart.fill" : "heart")
                                    .font(.title2)
                                    .foregroundStyle(repo.isFavorite(listing.id) ? Color.ooAccent : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        Text("$\(Int(listing.price))")
                            .font(.title.bold())
                            .foregroundStyle(Color.ooAccent)
                        Text(listing.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Label(listing.category.rawValue, systemImage: listing.category.icon)
                            Divider().frame(height: 16)
                            Label(listing.sellerName, systemImage: "person.crop.circle")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                        if listing.isDailyDeal, let end = listing.dealEndsAt {
                            HStack {
                                Image(systemName: "bolt.fill").foregroundStyle(.orange)
                                Text("Daily deal ends ").font(.caption.bold())
                                Text(end, style: .relative)
                                    .font(.caption.bold())
                                    .foregroundStyle(.orange)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal)

                    actionButtons
                        .padding(.horizontal)
                        .padding(.top, 8)

                    sellerCard
                        .padding(.horizontal)
                        .padding(.top, 12)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task { isFollowingSeller = FeedsService.shared.isFollowing(listing.sellerId) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Report listing", systemImage: "flag.fill", role: .destructive) {
                            postReport(reason: "Inappropriate listing", context: "feed")
                        }
                        Button("Share", systemImage: "square.and.arrow.up") {}
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    // MARK: - Action buttons

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                openChat()
            } label: {
                Label("Message", systemImage: "bubble.left.fill")
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.ooAccent)

            Button {
                startCall(audioOnly: true)
            } label: {
                Label("Call", systemImage: "phone.fill")
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)

            Button {
                startCall(audioOnly: false)
            } label: {
                Label("Video", systemImage: "video.fill")
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
        }
    }

    private var sellerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Seller").font(.headline)
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: "https://i.pravatar.cc/300?u=\(listing.sellerId)")) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default:                  Color.ooSurface
                    }
                }
                .frame(width: 56, height: 56).clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(listing.sellerName).font(.subheadline.bold())
                    Text("Top-rated seller • 4.9 ★")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !isOwnListing {
                    Button(isFollowingSeller ? "Following" : "Follow") {
                        toggleFollow()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isFollowingSeller ? Color(.systemGray3) : Color.ooAccent)
                    .controlSize(.small)
                }
            }

            HStack {
                Image(systemName: "checkmark.shield.fill").foregroundStyle(.green)
                Text("Stream Moderation: safe seller, no active reports.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Event bridges

    /// The CallContainer + InboxTabHost live underneath this sheet in the SwiftUI
    /// hierarchy. We MUST dismiss before posting any AppEvent, otherwise the call UI
    /// renders hidden under the sheet and the inbox deep-link target is invisible.
    private func bridge(after delay: TimeInterval = 0.35, _ work: @escaping () -> Void) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func openChat() {
        let title = listing.title
        let sellerId = listing.sellerId
        let listingId = listing.id

        if let channelId = listing.channelId {
            bridge {
                NotificationCenter.default.post(
                    name: AppEvents.openChat,
                    object: OpenChatRequest(channelId: channelId, listingTitle: title)
                )
            }
            return
        }

        // No pre-seeded channel - ask ChatService to spin one up before bridging.
        ChatService.shared.openListingChannel(
            listingId: listingId,
            peerId: sellerId,
            listingTitle: title
        ) { result in
            guard case .success(let bareId) = result else { return }
            bridge {
                NotificationCenter.default.post(
                    name: AppEvents.openChat,
                    object: OpenChatRequest(channelId: bareId, listingTitle: title)
                )
            }
        }
    }

    private func startCall(audioOnly: Bool) {
        let request = StartCallRequest(
            calleeId: listing.sellerId,
            calleeName: listing.sellerName,
            audioOnly: audioOnly,
            listingTitle: listing.title
        )
        bridge {
            NotificationCenter.default.post(name: AppEvents.startCall, object: request)
        }
    }

    private func toggleFollow() {
        let target = listing.sellerId
        let wasFollowing = isFollowingSeller
        isFollowingSeller.toggle() // optimistic UI
        Task {
            if wasFollowing {
                await FeedsService.shared.unfollow(target)
            } else {
                await FeedsService.shared.follow(target)
            }
            isFollowingSeller = FeedsService.shared.isFollowing(target)
        }
    }

    private func postReport(reason: String, context: String) {
        NotificationCenter.default.post(
            name: AppEvents.reportUser,
            object: ReportUserRequest(userId: listing.sellerId, reason: reason, context: context)
        )
    }
}
