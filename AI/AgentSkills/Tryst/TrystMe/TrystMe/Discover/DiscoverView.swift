//
//  DiscoverView.swift
//  TrystMe
//
//  The swipe deck. Owns the top card's drag offset so the action buttons and
//  the drag gesture share one spring-animated source of truth. Neutral.
//

import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var dragOffset: CGSize = .zero
    @State private var matchProfile: Profile?
    @State private var burstID = 0
    @State private var detailProfile: Profile?
    @State private var showFilters = false

    private let swipeThreshold: CGFloat = 110

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                    deck
                    actionButtons
                        .padding(.vertical, 18)
                }

                if burstID != 0 {
                    HeartBurstView()
                        .id(burstID)
                        .allowsHitTesting(false)
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $detailProfile) { ProfileDetailView(profile: $0) }
            .sheet(isPresented: $showFilters) { DiscoverFiltersSheet() }
            .overlay {
                if let match = matchProfile {
                    MatchOverlay(
                        me: appModel.currentProfile,
                        match: match,
                        onMessage: {
                            matchProfile = nil
                            appModel.selectedTab = .messages
                        },
                        onKeepSwiping: { matchProfile = nil }
                    )
                    .transition(.opacity)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(Brand.pink)
            Text("TrystMe")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Brand.pink)
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: 8)
            Button {
                showFilters = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var deck: some View {
        GeometryReader { geo in
            let cards = Array(appModel.discoverDeck.prefix(3))
            ZStack {
                if cards.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(cards.enumerated().reversed()), id: \.element.id) { index, profile in
                        let isTop = index == 0
                        SwipeCardView(
                            profile: profile,
                            isTop: isTop,
                            offset: isTop ? dragOffset : .zero,
                            onChanged: { dragOffset = $0 },
                            onEnded: { handleDragEnd($0, profile: profile) },
                            onInfo: { detailProfile = profile }
                        )
                        .scaleEffect(isTop ? 1 : 1 - CGFloat(index) * 0.04)
                        .offset(y: isTop ? 0 : CGFloat(index) * 12)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appModel.discoverDeck.count)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .padding(.horizontal, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 50)).foregroundStyle(Brand.pink)
            Text("You're all caught up!")
                .font(.title2.bold())
            Text("Check back soon for new people near you.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardSurface()
    }

    private var actionButtons: some View {
        HStack(spacing: 22) {
            circleButton(systemName: "arrow.uturn.backward", tint: .orange, size: 48) { rewind() }
            circleButton(systemName: "xmark", tint: .red, size: 62) { trigger(.pass) }
            circleButton(systemName: "star.fill", tint: Brand.purple, size: 52) { trigger(.superLike) }
            circleButton(systemName: "heart.fill", tint: Brand.pink, size: 62) { trigger(.like) }
        }
    }

    private func circleButton(systemName: String, tint: Color, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(Color(.systemBackground), in: Circle())
                .shadow(color: tint.opacity(0.25), radius: 8, y: 4)
        }
        .disabled(appModel.discoverDeck.isEmpty)
    }

    // MARK: - Swipe logic

    private func handleDragEnd(_ translation: CGSize, profile: Profile) {
        let h = translation.width, v = translation.height
        if v < -swipeThreshold && abs(h) < swipeThreshold {
            trigger(.superLike)
        } else if h > swipeThreshold {
            trigger(.like)
        } else if h < -swipeThreshold {
            trigger(.pass)
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { dragOffset = .zero }
        }
    }

    private func trigger(_ direction: SwipeDirection) {
        guard let profile = appModel.discoverDeck.first else { return }
        let target: CGSize
        switch direction {
        case .like: target = CGSize(width: 700, height: -60)
        case .pass: target = CGSize(width: -700, height: -60)
        case .superLike: target = CGSize(width: 0, height: -900)
        }
        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(direction == .pass ? .warning : .success)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { dragOffset = target }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            commit(direction, profile)
            dragOffset = .zero
        }
    }

    private func commit(_ direction: SwipeDirection, _ profile: Profile) {
        switch direction {
        case .pass:
            appModel.pass(profile)
        case .like, .superLike:
            burstID += 1
            let isMatch = appModel.like(profile)
            if isMatch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        matchProfile = profile
                    }
                }
            }
        }
    }

    private func rewind() {
        // Restore the most recently passed/liked profile to the top of the deck.
        if let last = appModel.passedIds.first {
            appModel.passedIds.remove(last)
        } else if let last = appModel.likedIds.first {
            appModel.likedIds.remove(last)
            appModel.matchedIds.remove(last)
        }
    }
}

/// Discovery preferences sheet opened from the Discover header.
struct DiscoverFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var ageRange: ClosedRange<Double> = 21...35
    @State private var maxDistance: Double = 25
    @State private var showMe = "Everyone"
    @State private var verifiedOnly = false

    private let showMeOptions = ["Women", "Men", "Everyone"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Show me") {
                    Picker("Show me", selection: $showMe) {
                        ForEach(showMeOptions, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Maximum distance") {
                    VStack(alignment: .leading) {
                        Text("\(Int(maxDistance)) miles")
                            .font(.subheadline.bold()).foregroundStyle(Brand.pink)
                        Slider(value: $maxDistance, in: 1...100, step: 1).tint(Brand.pink)
                    }
                }

                Section("Age range") {
                    VStack(alignment: .leading) {
                        Text("\(Int(ageRange.lowerBound)) – \(Int(ageRange.upperBound))")
                            .font(.subheadline.bold()).foregroundStyle(Brand.pink)
                        HStack {
                            Slider(value: Binding(
                                get: { ageRange.lowerBound },
                                set: { ageRange = min($0, ageRange.upperBound - 1)...ageRange.upperBound }
                            ), in: 18...80, step: 1).tint(Brand.pink)
                            Slider(value: Binding(
                                get: { ageRange.upperBound },
                                set: { ageRange = ageRange.lowerBound...max($0, ageRange.lowerBound + 1) }
                            ), in: 18...80, step: 1).tint(Brand.pink)
                        }
                    }
                }

                Section {
                    Toggle("Verified profiles only", isOn: $verifiedOnly).tint(Brand.pink)
                } footer: {
                    Text("TrystMe keeps you safe with circumvention & PII detection on every message.")
                }
            }
            .navigationTitle("Discovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
}
