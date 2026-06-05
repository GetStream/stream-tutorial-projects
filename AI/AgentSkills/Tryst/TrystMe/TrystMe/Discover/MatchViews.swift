//
//  MatchViews.swift
//  TrystMe
//
//  Spring-animated "It's a Match!" overlay and the floating heart burst that
//  fires when you like someone. Neutral (no Stream imports).
//

import SwiftUI

struct MatchOverlay: View {
    let me: Profile?
    let match: Profile
    let onMessage: () -> Void
    let onKeepSwiping: () -> Void

    @State private var appear = false

    var body: some View {
        ZStack {
            Brand.loveGradient.opacity(0.97).ignoresSafeArea()

            VStack(spacing: 28) {
                Text("It's a Match!")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .scaleEffect(appear ? 1 : 0.4)
                    .rotationEffect(.degrees(appear ? 0 : -8))

                Text("You and \(match.firstName) liked each other.")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.95))

                HStack(spacing: -24) {
                    avatar(me?.avatarURL)
                        .rotationEffect(.degrees(appear ? -6 : -40))
                        .offset(x: appear ? 0 : -120)
                    avatar(match.avatarURL)
                        .rotationEffect(.degrees(appear ? 6 : 40))
                        .offset(x: appear ? 0 : 120)
                }
                .overlay {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                        .scaleEffect(appear ? 1 : 0)
                        .shadow(radius: 8)
                }

                VStack(spacing: 12) {
                    Button(action: onMessage) {
                        Text("Send a Message")
                            .font(.headline).foregroundStyle(Brand.pink)
                            .padding(.vertical, 16).frame(maxWidth: .infinity)
                            .background(.white, in: Capsule())
                    }
                    Button(action: onKeepSwiping) {
                        Text("Keep Swiping")
                            .font(.headline).foregroundStyle(.white)
                            .padding(.vertical, 16).frame(maxWidth: .infinity)
                            .overlay(Capsule().stroke(.white, lineWidth: 1.5))
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 12)
                .opacity(appear ? 1 : 0)
            }
            .padding()
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { appear = true }
        }
    }

    private func avatar(_ url: URL?) -> some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: { Color.white.opacity(0.3) }
        .frame(width: 130, height: 130)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 4))
    }
}

/// A burst of hearts floating up from the bottom center.
struct HeartBurstView: View {
    @State private var fire = false
    private let count = 14

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    let angle = Double.random(in: -0.9...0.9)
                    let scale = CGFloat.random(in: 0.6...1.5)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 26))
                        .foregroundStyle([Brand.pink, Brand.coral, Brand.purple, .red].randomElement()!)
                        .scaleEffect(fire ? scale : 0.1)
                        .opacity(fire ? 0 : 1)
                        .offset(
                            x: fire ? CGFloat(angle) * geo.size.width * 0.5 : 0,
                            y: fire ? -geo.size.height * CGFloat.random(in: 0.4...0.85) : 0
                        )
                        .animation(
                            .easeOut(duration: Double.random(in: 0.9...1.5)).delay(Double(i) * 0.02),
                            value: fire
                        )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .position(x: geo.size.width / 2, y: geo.size.height * 0.78)
        }
        .onAppear { fire = true }
    }
}
