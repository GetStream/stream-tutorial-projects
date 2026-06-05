//
//  ProfileDetailView.swift
//  TrystMe
//
//  Full profile detail with photo carousel, bio, interests and actions
//  (like, message, audio/video call). Neutral (no Stream imports).
//

import SwiftUI

struct ProfileDetailView: View {
    let profile: Profile

    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var photoIndex = 0

    private var isMatched: Bool { appModel.isMatched(profile.id) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    carousel
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(profile.name).font(.largeTitle.bold())
                            Text("\(profile.age)").font(.title2).foregroundStyle(.secondary)
                            Spacer()
                            if isMatched {
                                Label("Matched", systemImage: "heart.fill")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Brand.pink.opacity(0.15), in: Capsule())
                                    .foregroundStyle(Brand.pink)
                            }
                        }
                        Label(profile.job, systemImage: "briefcase.fill").foregroundStyle(.secondary)
                        Label(profile.city, systemImage: "mappin.circle.fill").foregroundStyle(.secondary)

                        Divider()
                        Text("About").font(.headline)
                        Text(profile.bio).foregroundStyle(.primary)

                        Text("Interests").font(.headline).padding(.top, 4)
                        FlowPills(items: profile.interests)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 100)
            }
            .ignoresSafeArea(edges: .top)
            .overlay(alignment: .bottom) { actionBar }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.white) }
                }
            }
        }
    }

    private var carousel: some View {
        TabView(selection: $photoIndex) {
            ForEach(Array(profile.photos.enumerated()), id: \.offset) { idx, url in
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: { Brand.primaryGradient.opacity(0.3) }
                .tag(idx)
            }
        }
        .tabViewStyle(.page)
        .frame(height: 480)
        .clipped()
    }

    @ViewBuilder
    private var actionBar: some View {
        if isMatched {
            matchedCallControls
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        } else {
            HStack(spacing: 16) {
                actionButton("xmark", .red) { appModel.pass(profile); dismiss() }
                Button {
                    let matched = appModel.like(profile)
                    if !matched { dismiss() }
                } label: {
                    Label("Like", systemImage: "heart.fill").brandFilledButton()
                }
            }
            .padding(16)
            .background(.ultraThinMaterial)
        }
    }

    /// Liquid Glass container holding the message / audio / video controls.
    private var matchedCallControls: some View {
        GlassEffectContainer(spacing: 18) {
            HStack(spacing: 18) {
                glassControl("message.fill", Brand.pink) {
                    appModel.selectedTab = .messages
                    dismiss()
                }
                glassControl("phone.fill", .green) {
                    appModel.startCall(with: profile, video: false); dismiss()
                }
                glassControl("video.fill", Brand.purple) {
                    appModel.startCall(with: profile, video: true); dismiss()
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
        }
        .glassEffect(.regular.interactive(), in: .capsule)
        .frame(maxWidth: .infinity)
    }

    private func glassControl(_ icon: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 54, height: 54)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(tint.opacity(0.18)).interactive(), in: .circle)
    }

    private func actionButton(_ icon: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2.bold()).foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(tint, in: Circle())
                .shadow(color: tint.opacity(0.3), radius: 8, y: 4)
        }
    }
}

/// Simple wrapping pill layout for interests.
struct FlowPills: View {
    let items: [String]
    var body: some View {
        FlexibleWrap(items: items) { InterestPill(text: $0) }
    }
}

/// Lightweight flow layout using SwiftUI Layout protocol.
struct FlexibleWrap<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    var body: some View {
        WrapLayout(spacing: 8) {
            ForEach(items, id: \.self) { content($0) }
        }
    }
}

struct WrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
