//
//  LoginView.swift
//  ChatWithSkills
//
//  One-tap login picker for the demo. Real apps should swap this for
//  a backend-issued `TokenProvider` instead of bundled JWTs.
//

import SwiftUI
import StreamChat
import StreamChatSwiftUI

struct LoginView: View {
    @Injected(\.chatClient) private var chatClient

    let onConnected: () -> Void

    @State private var connectingUserID: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header

                    VStack(spacing: 12) {
                        ForEach(StreamConfig.demoUsers) { user in
                            userRow(user)
                        }
                    }
                    .padding(.horizontal)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.tint)
                .padding(.bottom, 4)
            Text("ChatWithSkills")
                .font(.largeTitle.bold())
            Text("Pick a demo user to start chatting.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 32)
    }

    private func userRow(_ user: DemoUser) -> some View {
        Button {
            connect(user)
        } label: {
            HStack(spacing: 14) {
                AsyncImage(url: user.imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.25))
                        .overlay(
                            Text(initials(for: user.name))
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        )
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("@\(user.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if connectingUserID == user.id {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(connectingUserID != nil)
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let initials = parts.prefix(2).compactMap { $0.first.map(String.init) }
        return initials.joined().uppercased()
    }

    private func connect(_ user: DemoUser) {
        connectingUserID = user.id
        errorMessage = nil

        let userInfo = UserInfo(
            id: user.id,
            name: user.name,
            imageURL: user.imageURL
        )
        let token = Token(stringLiteral: user.token)

        chatClient.connectUser(userInfo: userInfo, token: token) { error in
            DispatchQueue.main.async {
                connectingUserID = nil
                if let error {
                    errorMessage = "Could not connect: \(error.localizedDescription)"
                } else {
                    onConnected()
                }
            }
        }
    }
}

#Preview {
    LoginView(onConnected: {})
}
