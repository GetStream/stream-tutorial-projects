//
//  SearchView.swift
//  TrystMe
//
//  People search backed by Stream's user query (ChatService.searchProfiles).
//  Like / fave people directly from the results. Neutral (no Stream imports).
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var query = ""
    @State private var results: [Profile] = []
    @State private var isLoading = false
    @State private var detail: Profile?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if results.isEmpty && !isLoading {
                    ContentUnavailableView(
                        "Find your people",
                        systemImage: "magnifyingglass",
                        description: Text("Search by name to discover someone new.")
                    )
                } else {
                    List {
                        ForEach(results) { profile in
                            Button { detail = profile } label: { row(profile) }
                                .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .overlay { if isLoading { ProgressView() } }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Search people")
            .onChange(of: query) { _, _ in scheduleSearch() }
            .task { runSearch() }
            .sheet(item: $detail) { ProfileDetailView(profile: $0) }
        }
    }

    private func row(_ profile: Profile) -> some View {
        HStack(spacing: 14) {
            AsyncImage(url: profile.avatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: { Circle().fill(.gray.opacity(0.2)) }
            .frame(width: 56, height: 56)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("\(profile.name), \(profile.age)").font(.headline)
                Text("\(profile.job) · \(profile.city)")
                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            LikeHeartButton(isLiked: appModel.likedIds.contains(profile.id)) {
                _ = appModel.like(profile)
            }
        }
        .padding(.vertical, 4)
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled { runSearch() }
        }
    }

    private func runSearch() {
        isLoading = true
        ChatService.shared.searchProfiles(matching: query) { profiles in
            self.results = profiles.isEmpty ? localFallback() : profiles
            self.isLoading = false
        }
    }

    /// Fallback to the local roster if the server query returns nothing.
    private func localFallback() -> [Profile] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return Roster.all.filter {
            $0.id != appModel.currentUserId &&
            (q.isEmpty || $0.name.lowercased().contains(q))
        }
    }
}

/// A heart button with a springy pop when liked.
struct LikeHeartButton: View {
    let isLiked: Bool
    let action: () -> Void
    @State private var pop = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) { pop = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { pop = false }
            let gen = UIImpactFeedbackGenerator(style: .medium); gen.impactOccurred()
            action()
        } label: {
            Image(systemName: isLiked ? "heart.fill" : "heart")
                .font(.title2)
                .foregroundStyle(isLiked ? Brand.pink : .secondary)
                .scaleEffect(pop ? 1.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isLiked)
    }
}
