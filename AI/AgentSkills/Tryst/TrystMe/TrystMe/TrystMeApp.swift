//
//  TrystMeApp.swift
//  TrystMe
//
//  App entry point. Deliberately imports NO Stream module so it never trips the
//  cross-SDK type collisions. All Stream setup happens inside the isolated
//  services, triggered on login.
//

import SwiftUI

@main
struct TrystMeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appModel = AppModel.shared
    @StateObject private var notifications = NotificationManager.shared

    var body: some Scene {
        WindowGroup {
            AppGateView()
                .environmentObject(appModel)
                .environmentObject(notifications)
                .tint(Brand.pink)
        }
    }
}

/// Neutral app delegate used only to forward the APNs token to the services.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            NotificationManager.shared.didRegister(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Remote notification registration failed: \(error)")
    }
}

/// Switches between login, a connecting splash, and the main app.
struct AppGateView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        switch appModel.phase {
        case .loggedOut:
            LoginView()
        case .connecting:
            ConnectingView()
        case .loggedIn:
            RootView()
        }
    }
}

struct ConnectingView: View {
    var body: some View {
        ZStack {
            Brand.primaryGradient.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                ProgressView()
                    .tint(.white)
                Text("Finding your people…")
                    .foregroundStyle(.white.opacity(0.9))
                    .font(.headline)
            }
        }
    }
}
