//
//  AlertPushNotificationsApp.swift
//  AlertPushNotifications

import UIKit
import SwiftUI
import UserNotifications

// Step 1. Declare `UNUserNotificationCenterDelegate`
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application (_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        registerForNotifications()

        return true
    }
    
    // 2. Register for push notifications
    func registerForNotifications() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) {
                granted, error in
                print("Permission granted: \(granted)")
            }
    }
    
    // Step 3. Set up registration callback functions to check whether the registration fails or succeeds and display the notification.

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
            /*
             deviceToken.map { ... }: This maps over each byte in the deviceToken data. The map function applies the closure to each element of the deviceToken array.
                     String(format: "%02.2hhx", $0):
                     This part of the closure converts each byte ($0) of the device token into a two-character hexadecimal string.
                     "%02.2hhx" is a format specifier:
                     %02 ensures that each byte is represented by at least two characters, padding with zero if necessary.
                     .2hhx indicates that the byte should be formatted as a two-digit hexadecimal number.
                     .joined():
                 After mapping and converting each byte to a string, the resulting array of strings is joined into a single string. This creates a continuous string of hexadecimal characters representing the device token.
             */
            let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
            print(token)
        }
    
    
}

// MARK: Connect the app delegate to the SwiftUI app lifecycle
@main
struct AlertPushNotificationsApp: App {
    // Step 4. Connect the `AppDelegate` class to the SwiftUI app’s lifecycle
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}











