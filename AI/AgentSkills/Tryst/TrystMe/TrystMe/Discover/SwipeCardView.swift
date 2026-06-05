//
//  SwipeCardView.swift
//  TrystMe
//
//  A single profile card with Tinder-style LIKE / NOPE / FAVE stamps.
//  The drag offset is owned by DiscoverView so on-screen buttons and the drag
//  gesture share one spring-animated source of truth. Neutral (no Stream).
//

import SwiftUI

enum SwipeDirection { case like, pass, superLike }

struct SwipeCardView: View {
    let profile: Profile
    let isTop: Bool
    let offset: CGSize
    var onChanged: (CGSize) -> Void = { _ in }
    var onEnded: (CGSize) -> Void = { _ in }
    var onInfo: () -> Void = {}

    @State private var photoIndex = 0

    private let swipeThreshold: CGFloat = 110
    private var rotation: Double { Double(offset.width / 18) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                photo
                photoTapZones
                bottomGradient
                stamps
                gradientInfo
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 10)
            .offset(offset)
            .rotationEffect(.degrees(rotation), anchor: .bottom)
            .gesture(isTop ? dragGesture : nil)
        }
    }

    private var bottomGradient: some View {
        LinearGradient(colors: [.clear, .clear, .black.opacity(0.78)],
                       startPoint: .top, endPoint: .bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
    }

    private var photo: some View {
        AsyncImage(url: profile.photos[safe: photoIndex] ?? profile.avatarURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            ZStack {
                Brand.primaryGradient.opacity(0.4)
                ProgressView().tint(.white)
            }
        }
    }

    private var photoTapZones: some View {
        HStack(spacing: 0) {
            Color.clear.contentShape(Rectangle()).onTapGesture {
                withAnimation(.bouncy(duration: 1.0, extraBounce: 0.4)) { photoIndex = max(0, photoIndex - 1) }
            }
            Color.clear.contentShape(Rectangle()).onTapGesture {
                withAnimation(.bouncy(duration: 1.0, extraBounce: 0.4)) {
                    photoIndex = min(profile.photos.count - 1, photoIndex + 1)
                }
            }
        }
    }

    private var stamps: some View {
        VStack {
            HStack {
                stamp("LIKE", color: .green, rotation: -18)
                    .opacity(Double(max(0, offset.width) / swipeThreshold))
                    
                Spacer()
                stamp("NOPE", color: .red, rotation: 18)
                    .opacity(Double(max(0, -offset.width) / swipeThreshold))
            }
            .padding(.horizontal, 24)
            
            Spacer()
            stamp("FAVE", color: Brand.purple, rotation: -8)
                .opacity(Double(max(0, -offset.height) / swipeThreshold))
                .padding(.bottom, 90)
        }
        .padding(24)
    }

    private func stamp(_ text: String, color: Color, rotation: Double) -> some View {
        Text(text)
            .font(.system(size: 36, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color, lineWidth: 4))
            .rotationEffect(.degrees(rotation))
    }

    private var gradientInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            if profile.photos.count > 1 {
                HStack(spacing: 4) {
                    ForEach(0..<profile.photos.count, id: \.self) { i in
                        Capsule().fill(.white.opacity(i == photoIndex ? 1 : 0.4)).frame(height: 3)
                    }
                }
                .padding(.bottom, 4)
            }
            
            VStack (alignment: .leading) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(profile.firstName)
                        .font(.title.weight(.bold))
                    Text("\(profile.age)")
                    Spacer(minLength: 8)
                    Button(action: onInfo) {
                        Image(systemName: "info.circle.fill").font(.title).foregroundStyle(.white)
                    }
                }
                .foregroundStyle(.white)
                .padding(32)

                
                Label(profile.job, systemImage: "briefcase.fill")
                        .font(.subheadline.weight(.medium))
                Label(profile.city, systemImage: "mappin.circle.fill")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
               

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(profile.interests.prefix(4), id: \.self) { interest in
                            Text(interest)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(.white.opacity(0.22), in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { onChanged($0.translation) }
            .onEnded { onEnded($0.translation) }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
