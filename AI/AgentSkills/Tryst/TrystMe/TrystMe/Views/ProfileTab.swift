//
//  ProfileTab.swift
//  TrystMe
//
//  The signed-in user's own profile + account actions. Neutral (no Stream
//  imports) — it reads the local roster and routes logout through AppModel.
//

import SwiftUI

struct ProfileTab: View {
    @EnvironmentObject private var appModel: AppModel

    private var me: Profile? { appModel.currentProfile }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let me {
                    VStack(spacing: 20) {
                        header(me)
                        statsRow
                        section("About") {
                            Text(me.bio).foregroundStyle(.primary)
                        }
                        section("Interests") {
                            FlowPills(items: me.interests)
                        }
                        section("Safety") {
                            Label("Circumvention & PII detection is on", systemImage: "checkmark.shield.fill")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                            Text("Messages that share phone numbers, payment details, or push you off TrystMe are held for review.")
                                .font(.caption).foregroundStyle(.secondary)
                        }

                        Button(role: .destructive) { appModel.logout() } label: {
                            Text("Log out").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("My Profile")
        }
    }

    private func header(_ profile: Profile) -> some View {
        VStack(spacing: 12) {
            AsyncImage(url: profile.avatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: { Circle().fill(.gray.opacity(0.2)) }
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .overlay(Circle().stroke(Brand.primaryGradient, lineWidth: 3))
            .shadow(color: Brand.pink.opacity(0.3), radius: 12, y: 6)

            Text("\(profile.name), \(profile.age)").font(.title2.bold())
            Label("\(profile.job) · \(profile.city)", systemImage: "briefcase.fill")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            stat("\(appModel.matchedIds.count)", "Matches")
            Divider().frame(height: 36)
            stat("\(appModel.likedIds.count)", "Likes sent")
            Divider().frame(height: 36)
            stat("\(Roster.likesYouBack.count)", "Admirers")
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .cardSurface(cornerRadius: 18)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.bold()).foregroundStyle(Brand.pink)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
