//
//  LoginView.swift
//  TrystMe
//
//  Brand splash + demo profile picker. Because tokens are pre-generated per
//  roster user, you can sign in as anyone and they can really chat/call/follow
//  each other. No Stream imports here.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var selected: String = Roster.currentUserId
    @State private var animateHeart = false

    private var profiles: [Profile] { Roster.all }
    private var selectedProfile: Profile { Roster.profile(selected) ?? Roster.all[0] }

    var body: some View {
        ZStack {
            Brand.primaryGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                // Brand mark
                VStack(spacing: 10) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(animateHeart ? 1.0 : 0.8)
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
                    Text("TrystMe")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Find love, intimacy & everything in between.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.bottom, 28)

                // Selected profile preview
                selectedCard
                    .padding(.horizontal, 28)
                    .padding(.bottom, 18)

                Text("Choose who to sign in as")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.bottom, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(profiles) { profile in
                            avatarChoice(profile)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 6)
                }

                Button {
                    Task { await appModel.login(as: selected) }
                } label: {
                    Text("Continue as \(selectedProfile.firstName)")
                        .font(.headline)
                        .foregroundStyle(Brand.pink)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(.white, in: Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 6)
                }
                .padding(.horizontal, 28)
                .padding(.top, 18)

                Text("Demo tokens · powered by Stream Chat, Video & Feeds")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 12)

                Spacer(minLength: 24)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5).repeatForever(autoreverses: true)) {
                animateHeart = true
            }
        }
    }

    private var selectedCard: some View {
        HStack(spacing: 16) {
            AsyncImage(url: selectedProfile.avatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: { Color.white.opacity(0.3) }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 3))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(selectedProfile.name), \(selectedProfile.age)")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text("\(selectedProfile.job) · \(selectedProfile.city)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
        }
        .padding(16)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func avatarChoice(_ profile: Profile) -> some View {
        let isSelected = profile.id == selected
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { selected = profile.id }
        } label: {
            VStack(spacing: 6) {
                AsyncImage(url: profile.avatarURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: { Color.white.opacity(0.3) }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: isSelected ? 3 : 0))
                .scaleEffect(isSelected ? 1.12 : 1.0)
                Text(profile.firstName)
                    .font(.caption2.weight(isSelected ? .bold : .regular))
                    .foregroundStyle(.white.opacity(isSelected ? 1 : 0.75))
            }
        }
        .buttonStyle(.plain)
    }
}
