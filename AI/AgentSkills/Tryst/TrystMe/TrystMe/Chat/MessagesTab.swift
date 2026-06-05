//
//  MessagesTab.swift
//  TrystMe
//
//  Neutral matches list. Navigates to MatchChatView (the Stream-Chat-isolated
//  conversation). No Stream imports here.
//

import SwiftUI

struct MessagesTab: View {
    @EnvironmentObject private var appModel: AppModel

    private var matches: [Profile] {
        appModel.matchedIds.compactMap { Roster.profile($0) }
            .filter { $0.id != appModel.currentUserId }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            Group {
                if matches.isEmpty {
                    ContentUnavailableView(
                        "No matches yet",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Like people in Discover. When it's mutual, you can chat here.")
                    )
                } else {
                    List(matches) { profile in
                        NavigationLink {
                            MatchChatView(otherUserId: profile.id, otherName: profile.name,
                                          otherImage: profile.avatarURL.absoluteString)
                        } label: {
                            row(profile)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Matches")
        }
    }

    private func row(_ profile: Profile) -> some View {
        HStack(spacing: 14) {
            AsyncImage(url: profile.avatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: { Circle().fill(.gray.opacity(0.2)) }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
            .overlay(Circle().stroke(Brand.primaryGradient, lineWidth: 2))

            VStack(alignment: .leading, spacing: 3) {
                Text(profile.firstName).font(.headline)
                Text("Say hi to \(profile.firstName) 👋")
                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
