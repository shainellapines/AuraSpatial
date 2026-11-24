//
//  AuraSpatialApp.swift
//  AuraSpatial
//
//  App entry point. Picks the data backend first (Firebase when it's set
//  up, on-device storage otherwise - see Backend.swift), then injects the AuthController (the session Controller) into
//  the environment (plus SettingsController, so preferences survive
//  logging out and back in), applies the app-wide violet tint and forced dark scheme
//  matching the prototype, and attempts to restore a previously simulated
//  session (FR-1.1, FR-1.3).
//

import SwiftUI

@main
struct AuraSpatialApp: App {
    @State private var authController: AuthController
    @State private var settingsController: SettingsController

    init() {
        // Must run before any Controller asks Backend for a repository.
        Backend.configure()
        _authController = State(initialValue: AuthController())
        _settingsController = State(initialValue: SettingsController())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authController)
                .environment(settingsController)
                .preferredColorScheme(.dark)
                .tint(.auraViolet)
                .task {
                    // Quick restore, no artificial delays
                    await authController.restoreSession()
                }
        }
    }
}
