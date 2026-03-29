//
//  ShieldActionExtension.swift
//  ShieldActionExtension
//
//  Created by ENRELLA TUTU on 17/03/2026.
//

import ManagedSettings
import UserNotifications

// Override the functions below to customize the shield actions used in various situations.
// The system provides a default response for any functions that your subclass doesn't override.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            scheduleOpenAyahNotification()
            completionHandler(.none)
        case .secondaryButtonPressed:
            completionHandler(.defer)
        @unknown default:
            completionHandler(.defer)
        }
    }

    /// Schedule a local notification so the user can tap the banner to open Tilawa and go to the read screen.
    private func scheduleOpenAyahNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Ready to read?"
        content.body = "Tap here to read your Ayah and unlock your apps."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "tilawa.open_ayah_reader",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.3, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        // Handle the action as needed.
        completionHandler(.close)
    }
    
    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            // Same behavior as app-level shields: nudge user into Tilawa to read and unlock.
            scheduleOpenAyahNotification()
            completionHandler(.none)
        case .secondaryButtonPressed:
            completionHandler(.defer)
        @unknown default:
            completionHandler(.defer)
        }
    }
}
