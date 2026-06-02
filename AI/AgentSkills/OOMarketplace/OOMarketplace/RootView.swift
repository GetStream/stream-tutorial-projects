//
//  RootView.swift
//  OOMarketplace
//
//  No Stream imports. The TabView shell hosts five tabs; each tab's content is
//  defined in its own isolated file so Chat / Video / Feeds imports never collide.
//

import SwiftUI

enum AppTab: Hashable {
    case discover, feed, sell, inbox, profile
}

struct RootView: View {
    @State private var selectedTab: AppTab = .discover

    var body: some View {
        TabView(selection: $selectedTab) {
            DiscoverView()
                .tabItem { Label("Discover", systemImage: "sparkles") }
                .tag(AppTab.discover)

            FeedTabHost()
                .tabItem { Label("Feed", systemImage: "rectangle.stack") }
                .tag(AppTab.feed)

            SellView()
                .tabItem { Label("Sell", systemImage: "plus.app.fill") }
                .tag(AppTab.sell)

            InboxTabHost()
                .tabItem { Label("Inbox", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(AppTab.inbox)

            ProfileTabHost()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
        .tint(.accentColor)
        // Cross-feature deep links
        .onReceive(NotificationCenter.default.publisher(for: AppEvents.openChat)) { _ in
            selectedTab = .inbox
        }
        .onReceive(NotificationCenter.default.publisher(for: AppEvents.openListing)) { _ in
            selectedTab = .discover
        }
    }
}

// MARK: - Brand color

extension Color {
    static let ooAccent = Color(red: 0.96, green: 0.39, blue: 0.27)
    static let ooSurface = Color(.secondarySystemBackground)
}
