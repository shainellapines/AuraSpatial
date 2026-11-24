//
//  CommunityController.swift
//  AuraSpatial
//
//  The Controller for the Community Feed (SRS Section 3.4): browse,
//  preview-play (FR-5.1), like, fork, and share soundscapes. With Firebase,
//  the feed is a shared Firestore collection and likes/forks are counted
//  for everyone; without it, the bundled samples are shown. Fork itself is
//  delegated to SavedLayoutsController from the View layer.
//
//  Preview now plays REAL spatial audio: the tapped soundscape's sounds
//  are placed in their actual positions on a separate SpatialAudioEngine,
//  so you hear the layout in 3D before forking it. Only one preview plays
//  at a time, and the View mutes the Canvas while one is playing.
//

import Foundation
import Observation

@Observable
final class CommunityController {
    private(set) var feed: [Soundscape] = []
    /// The soundscape currently previewing, if any - only one plays at a time.
    private(set) var playingID: UUID?
    private(set) var likedIDs: Set<UUID> = []

    private let repository: CommunityRepository
    private let likesStore: LikesStore
    /// Created on first preview, so launching the app starts one engine, not two.
    @ObservationIgnored private var previewEngine: SpatialAudioEngine?
    @ObservationIgnored private var settings = AppSettings()

    init(repository: CommunityRepository? = nil, likesStore: LikesStore? = nil) {
        let store = likesStore ?? LikesStore()
        self.repository = repository ?? Backend.makeCommunityRepository()
        self.likesStore = store
        self.likedIDs = store.load()
    }

    /// Whether "Share to Community" is available (needs Firebase).
    var canShare: Bool { repository.supportsSharing }

    func refresh() async {
        feed = (try? await repository.fetchFeed()) ?? []
    }

    /// Shares a saved layout to the feed under the user's username.
    func share(_ layout: Soundscape, as username: String) async throws {
        try await repository.publish(layout, as: username)
        await refresh()
    }

    func togglePlay(_ soundscape: Soundscape) {
        if playingID == soundscape.id {
            stopPreview()
            return
        }
        let engine = engineForPreview()
        engine.removeAllNodes()
        for node in soundscape.nodes.prefix(CanvasController.maxNodes) {
            if let asset = SoundAsset.resolve(node) {
                engine.addNode(node.clampedToUnitCircle(), asset: asset)
            }
        }
        playingID = soundscape.id
    }

    func stopPreview() {
        previewEngine?.removeAllNodes()
        playingID = nil
    }

    func isPlaying(_ id: UUID) -> Bool {
        playingID == id
    }

    func isLiked(_ id: UUID) -> Bool {
        likedIDs.contains(id)
    }

    func likeCount(for soundscape: Soundscape) -> Int {
        soundscape.likeCount
    }

    /// Updates the count on screen right away, remembers the like on this
    /// device, and sends +1 / -1 to the repository.
    func toggleLike(_ id: UUID) {
        let delta: Int
        if likedIDs.contains(id) {
            likedIDs.remove(id)
            delta = -1
        } else {
            likedIDs.insert(id)
            delta = 1
        }
        likesStore.save(likedIDs)
        adjust(id) { $0.likeCount = max(0, $0.likeCount + delta) }
        Task { await repository.changeLikes(of: id, by: delta) }
    }

    func recordFork(_ id: UUID) {
        adjust(id) { $0.forkCount += 1 }
        Task { await repository.recordFork(of: id) }
    }

    private func adjust(_ id: UUID, _ change: (inout Soundscape) -> Void) {
        guard let index = feed.firstIndex(where: { $0.id == id }) else { return }
        change(&feed[index])
    }

    func apply(_ newSettings: AppSettings) {
        settings = newSettings
        previewEngine?.setMasterVolume(newSettings.masterVolume)
        previewEngine?.setSpatialMode(newSettings.spatialMode)
    }

    private func engineForPreview() -> SpatialAudioEngine {
        if let previewEngine {
            return previewEngine
        }
        let engine = SpatialAudioEngine()
        engine.setMasterVolume(settings.masterVolume)
        engine.setSpatialMode(settings.spatialMode)
        previewEngine = engine
        return engine
    }
}
