//
//  SessionNotifier.swift
//  AuraSpatial
//
//  Schedules the local notification that says a Focus or Sleep session
//  has ended (UserNotifications framework - no server needed).
//
//  The notification is scheduled the moment a timer starts, with a
//  time-interval trigger set to the session's remaining time. iOS delivers
//  it itself, so it arrives even if the app is in the background, the
//  phone is locked, or the app was closed. While the app is open, iOS
//  doesn't show it (no foreground delegate), because the Canvas already
//  shows its own "session complete" banner.
//
//  Sleep sessions are delivered silently, so the alert can't wake you up.
//

import Foundation
import UserNotifications

enum NotificationPermission {
    case notDetermined
    case allowed
    case denied
}

final class SessionNotifier {
    private let center: UNUserNotificationCenter
    private let identifier = "auraspatial.session.end"

    init(center: UNUserNotificationCenter? = nil) {
        self.center = center ?? UNUserNotificationCenter.current()
    }

    func permission() async -> NotificationPermission {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .allowed
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        @unknown default:
            return .denied
        }
    }

    /// Shows the system permission prompt the first time only. Returns
    /// whether alerts are allowed afterwards.
    func requestPermissionIfNeeded() async -> Bool {
        switch await permission() {
        case .allowed:
            return true
        case .denied:
            return false
        case .notDetermined:
            let granted = try? await center.requestAuthorization(options: [.alert, .sound])
            return granted ?? false
        }
    }

    /// Schedules "session complete" for when `timer` ends, replacing any
    /// earlier one.
    func scheduleSessionEnd(for timer: SessionTimer) async {
        cancelSessionEnd()
        guard await requestPermissionIfNeeded() else { return }

        // Measured after the permission prompt, which can take a while.
        let remaining = timer.remaining(at: Date())
        guard remaining > 1 else { return }

        let minutes = max(1, Int((timer.duration / 60).rounded()))
        let content = UNMutableNotificationContent()
        content.title = timer.mode.completionTitle
        switch timer.mode {
        case .focus:
            content.body = "Your \(minutes)-minute focus soundscape has faded out. Time for a break."
            content.sound = .default
        case .sleep:
            content.body = "Your soundscape faded out after \(minutes) \(minutes == 1 ? "minute" : "minutes"). Sleep well."
            content.sound = nil
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func cancelSessionEnd() {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
