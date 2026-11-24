//
//  RootTabView.swift
//  AuraSpatial
//
//  The post-login shell: Canvas · Community · Saved · Profile (SRS
//  Section 5). Owns and injects the screen Controllers so sibling tabs can
//  share state (e.g. Saved Layouts reading the Canvas's current nodes to
//  overwrite), plus an AppRouter so one tab can switch to another.
//
//  It also watches Settings: every change is saved and pushed to both
//  audio engines immediately.
//

import SwiftUI

struct RootTabView: View {
    @Environment(SettingsController.self) private var settingsController

    @State private var router = AppRouter()
    @State private var canvasController = CanvasController()
    @State private var communityController = CommunityController()
    @State private var savedLayoutsController = SavedLayoutsController()

    var body: some View {
        TabView(selection: $router.selectedTab) {
            CanvasView()
                .tabItem { Label("Canvas", systemImage: "waveform") }
                .tag(AppTab.canvas)

            CommunityFeedView()
                .tabItem { Label("Community", systemImage: "person.2.fill") }
                .tag(AppTab.community)

            SavedLayoutsView()
                .tabItem { Label("Saved", systemImage: "square.grid.2x2.fill") }
                .tag(AppTab.saved)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
        .tint(.auraViolet)
        .toolbarBackground(Color.auraSurface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .environment(router)
        .environment(canvasController)
        .environment(communityController)
        .environment(savedLayoutsController)
        .onChange(of: settingsController.settings, initial: true) { _, newSettings in
            settingsController.save()
            canvasController.apply(newSettings)
            communityController.apply(newSettings)
        }
        .task {
            await savedLayoutsController.refresh()
            await communityController.refresh()
        }
    }
}
