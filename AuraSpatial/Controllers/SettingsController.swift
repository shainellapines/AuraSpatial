//
//  SettingsController.swift
//  AuraSpatial
//
//  The Controller for app preferences (Profile > Settings). Views bind
//  directly to `settings`; RootTabView watches it, saves it, and pushes it
//  to the audio Controllers whenever anything changes.
//

import Foundation
import Observation

@Observable
final class SettingsController {
    var settings: AppSettings
    /// Whether iOS currently lets AuraSpatial show notifications.
    private(set) var notificationPermission: NotificationPermission = .notDetermined

    private let store: SettingsStore
    private let notifier: SessionNotifier

    init(store: SettingsStore? = nil, notifier: SessionNotifier? = nil) {
        let resolvedStore = store ?? SettingsStore()
        self.store = resolvedStore
        self.notifier = notifier ?? SessionNotifier()
        self.settings = resolvedStore.load()
    }

    func refreshNotificationPermission() async {
        notificationPermission = await notifier.permission()
    }

    /// Turning alerts on asks iOS for permission the first time.
    func setNotificationsEnabled(_ isEnabled: Bool) async {
        settings.notificationsEnabled = isEnabled
        if isEnabled {
            _ = await notifier.requestPermissionIfNeeded()
        }
        await refreshNotificationPermission()
    }

    func save() {
        store.save(settings)
    }

    func resetToDefaults() {
        settings = AppSettings()
        store.save(settings)
    }
}
