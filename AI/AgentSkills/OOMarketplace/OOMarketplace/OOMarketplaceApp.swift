//
//  OOMarketplaceApp.swift
//  OOMarketplace
//
//  Entry point - no Stream SDK imports. All SDK setup happens inside the three
//  isolated service files (ChatService / VideoService / FeedsService).
//

import SwiftUI

@main
struct OOMarketplaceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            CallShell()
        }
    }
}
