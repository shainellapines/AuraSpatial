//
//  CommunityFeedView.swift
//  AuraSpatial
//
//  Screen 8 (SRS Section 5): browse, preview-play, like, and fork
//  (FR-5.1, FR-5.2). Preview now plays the soundscape for real, in 3D;
//  the Canvas is muted while a preview plays and the preview stops when
//  you leave this tab.
//

import SwiftUI

struct CommunityFeedView: View {
    @Environment(CommunityController.self) private var communityController
    @Environment(SavedLayoutsController.self) private var savedLayoutsController
    @Environment(CanvasController.self) private var canvasController
    @Environment(SettingsController.self) private var settingsController

    @State private var toastMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.auraBackground.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        Label(communityController.canShare
                              ? "Tap play to hear a layout in 3D. Share your own from Saved Layouts."
                              : "Tap play to hear a layout in 3D. Headphones recommended.",
                              systemImage: "headphones")
                            .font(.caption)
                            .foregroundStyle(.auraTextSecondary)
                            .padding(.horizontal, 4)

                        ForEach(communityController.feed) { soundscape in
                            CommunitySoundscapeCardView(
                                soundscape: soundscape,
                                isPlaying: communityController.isPlaying(soundscape.id),
                                isLiked: communityController.isLiked(soundscape.id),
                                likeCount: communityController.likeCount(for: soundscape),
                                onPlayToggle: { communityController.togglePlay(soundscape) },
                                onLike: { communityController.toggleLike(soundscape.id) },
                                onFork: { fork(soundscape) }
                            )
                        }
                    }
                    .padding(20)
                }
                .refreshable {
                    await communityController.refresh()
                }
            }
            .navigationTitle("Community")
            .toolbarBackground(Color.auraBackground, for: .navigationBar)
            .auraToast($toastMessage)
            .sensoryFeedback(.impact(weight: .light), trigger: communityController.playingID) { _, _ in
                settingsController.settings.hapticsEnabled
            }
            .onChange(of: communityController.playingID) { _, newValue in
                canvasController.setDucked(newValue != nil)
            }
            .onDisappear {
                communityController.stopPreview()
                canvasController.setDucked(false)
            }
            .task {
                await communityController.refresh()
            }
        }
    }

    private func fork(_ soundscape: Soundscape) {
        communityController.recordFork(soundscape.id)
        Task {
            let forked = await savedLayoutsController.fork(soundscape)
            toastMessage = "Forked to Saved as “\(forked.name)”"
        }
    }
}
