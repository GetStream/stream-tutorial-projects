//
//  MainTabView.swift
//  TrystMe
//
//  Neutral tab shell. Hosts feature screens that internally use the isolated
//  Stream services — but this file imports no Stream module.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        TabView(selection: $appModel.selectedTab) {
            DiscoverView()
                .tabItem { Label("Discover", systemImage: "flame.fill") }
                .tag(AppModel.Tab.discover)

            FeedTab()
                .tabItem { Label("Feed", systemImage: "sparkles") }
                .tag(AppModel.Tab.feed)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(AppModel.Tab.search)

            MessagesTab()
                .tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(AppModel.Tab.messages)

            ProfileTab()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(AppModel.Tab.profile)
        }
    }
}
