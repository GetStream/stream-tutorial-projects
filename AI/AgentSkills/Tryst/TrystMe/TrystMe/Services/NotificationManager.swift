//
//  NotificationManager.swift
//  TrystMe
//
//  Neutral push-notification coordinator. Requests permission, registers for
//  remote notifications, and forwards the APNs token to the Stream services so
//  Chat + Feeds can deliver realtime alerts (messages, replies, reactions,
//  follows, likes). No Stream imports — it talks to the services only.
//

import Foundation
import Combine
import UIKit
import UserNotifications

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var authorized = false

    private override init() { super.init() }

    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            authorized = granted
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            print("Notification authorization error: \(error)")
        }
    }

    /// Called from the AppDelegate when APNs returns a device token.
    func didRegister(deviceToken: Data) {
        ChatService.shared.registerDevice(token: deviceToken)
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        FeedsService.shared.registerDevice(token: hex)
    }

    /// Local fallback banner (e.g. for in-session alerts on the simulator).
    func postLocalAlert(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
