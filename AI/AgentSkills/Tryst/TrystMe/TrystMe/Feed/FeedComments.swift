//
//  FeedComments.swift
//  TrystMe
//
//  ISOLATED Stream Feeds file (StreamFeeds + StreamCore only).
//  Threaded comments built on the Activity / ActivityState objects.
//

import SwiftUI
import StreamCore
import StreamFeeds

struct CommentsSheet: View {
    let activityId: String
    let feed: Feed
    let client: FeedsClient

    @State private var activity: Activity
    @StateObject private var activityState: ActivityState
    @State private var replyToId: String?
    @State private var commentText = ""
    @State private var isSubmitting = false
    @Environment(\.dismiss) private var dismiss

    init(activityId: String, feed: Feed, client: FeedsClient) {
        self.activityId = activityId
        self.feed = feed
        self.client = client
        let a = client.activity(for: activityId, in: feed.feed)
        _activity = State(initialValue: a)
        _activityState = StateObject(wrappedValue: a.state)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if activityState.comments.isEmpty {
                        Text("No comments yet. Say hi 👋")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }
                    ForEach(activityState.comments, id: \.id) { comment in
                        CommentRow(comment: comment, activity: activity, onReply: { replyToId = comment.id })
                        if let replies = comment.replies {
                            ForEach(replies, id: \.id) { reply in
                                CommentRow(comment: reply, activity: activity, onReply: { replyToId = comment.id })
                                    .padding(.leading, 40)
                            }
                        }
                    }
                }
                .padding()
            }
            .task { try? await activity.get() }
            .safeAreaInset(edge: .bottom) { inputBar }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField(replyToId != nil ? "Reply…" : "Add a comment…", text: $commentText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
            Button { Task { await submit() } } label: {
                Image(systemName: "arrow.up.circle.fill").font(.title)
                    .foregroundStyle(commentText.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : Brand.pink)
            }
            .disabled(commentText.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
        }
        .padding(.horizontal).padding(.vertical, 8)
        .background(.bar)
    }

    private func submit() async {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSubmitting = true
        try? await activity.addComment(
            request: .init(comment: trimmed, createNotificationActivity: true, parentId: replyToId)
        )
        commentText = ""
        replyToId = nil
        isSubmitting = false
    }
}

struct CommentRow: View {
    let comment: ThreadedCommentData
    let activity: Activity
    let onReply: () -> Void

    private var hasLiked: Bool { !comment.ownReactions.filter { $0.type == "heart" }.isEmpty }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: comment.user.imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: { Circle().fill(.gray.opacity(0.2)) }
            .frame(width: 32, height: 32).clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(comment.user.name ?? comment.user.id).font(.subheadline.bold())
                if let text = comment.text { Text(text) }
                HStack(spacing: 16) {
                    Button("Reply", action: onReply)
                    Button {
                        Task {
                            if hasLiked {
                                try? await activity.deleteCommentReaction(commentId: comment.id, type: "heart")
                            } else {
                                try? await activity.addCommentReaction(commentId: comment.id, request: .init(type: "heart"))
                            }
                        }
                    } label: {
                        Label("\(comment.reactionGroups["heart"]?.count ?? 0)",
                              systemImage: hasLiked ? "heart.fill" : "heart")
                            .foregroundStyle(hasLiked ? Brand.pink : .secondary)
                    }
                }
                .font(.caption).buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
    }
}
