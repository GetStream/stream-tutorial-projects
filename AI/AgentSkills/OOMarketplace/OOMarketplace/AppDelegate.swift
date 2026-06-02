//
//  AppDelegate.swift
//  OOMarketplace
//
//  No Stream imports. Bootstraps the three isolated Stream services and forwards
//  APNs registration to each of them via their own static helpers (which DO have the
//  required SDK imports inside their own file).
//

import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        // Initialize all three Stream services (Chat, Video, Feeds) with file isolation.
        // Each .setUp() is defined in its own SDK-isolated file - this file does NOT
        // import StreamChat / StreamVideo / StreamFeeds, so the colliding `User`,
        // `Token`, `ViewFactory`, and `@Injected` symbols never appear here.
        ChatService.shared.setUp()
        VideoService.shared.setUp()
        FeedsService.shared.setUp()

        // Local notifications power the demo experience for daily deals, order updates,
        // and delivery alerts when remote APNs is not configured yet.
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                    AppDelegate.scheduleDemoMarketplaceAlerts()
                }
            }
        }

        return true
    }

    // MARK: - Push token forwarding

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02hhx", $0) }.joined()
        Task { @MainActor in
            ChatService.shared.registerDevice(tokenHex: hex)
            VideoService.shared.registerDevice(tokenHex: hex)
            await FeedsService.shared.registerDevice(tokenHex: hex)
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Demo environment - log and continue. Local UNUserNotificationCenter alerts
        // still drive the marketplace push experience on simulator.
        print("[Push] Remote registration failed: \(error.localizedDescription)")
    }

    // MARK: - Foreground display + tap handling

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        if let channelId = info["channelId"] as? String {
            NotificationCenter.default.post(
                name: AppEvents.openChat,
                object: OpenChatRequest(channelId: channelId, listingTitle: info["listingTitle"] as? String)
            )
        } else if let listingId = info["listingId"] as? String {
            NotificationCenter.default.post(name: AppEvents.openListing, object: listingId)
        }
        completionHandler()
    }

    // MARK: - Demo marketplace pushes (local)

    /// Schedules three local notifications so the marketplace push experience works end-to-end
    /// without provisioning APNs/Firebase. Real production builds would hand off to the Stream
    /// push providers (configured per service in their `setUp()` calls).
    @MainActor
    static func scheduleDemoMarketplaceAlerts() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let deals = MarketplaceRepository.shared.dailyDeals()
        let alerts: [(title: String, body: String, after: TimeInterval, info: [AnyHashable: Any])] = [
            (
                title: "Daily Deal • -25%",
                body: deals.first.map { "\($0.title) just dropped to $\(Int($0.price * 0.75))." } ?? "New daily deal in your feed.",
                after: 8,
                info: [
                    "listingId": deals.first?.id ?? "",
                    "channelId": deals.first?.channelId ?? "",
                    "listingTitle": deals.first?.title ?? ""
                ]
            ),
            (
                title: "Order on the way",
                body: "Your AirPods Pro 2 left the warehouse. Tap to chat with the seller.",
                after: 18,
                info: [
                    "listingId": "listing-003",
                    "channelId": "listing-airpods",
                    "listingTitle": "AirPods Pro 2 with MagSafe"
                ]
            ),
            (
                title: "Delivery update",
                body: "Carbon Road Bike • Out for delivery in 30 mins.",
                after: 30,
                info: [
                    "listingId": "listing-004",
                    "channelId": "listing-roadbike",
                    "listingTitle": "Carbon Fiber Road Bike (54cm)"
                ]
            )
        ]

        for (i, alert) in alerts.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body = alert.body
            content.sound = .default
            content.userInfo = alert.info

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: alert.after, repeats: false)
            let request = UNNotificationRequest(
                identifier: "demo.alert.\(i)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }
}
