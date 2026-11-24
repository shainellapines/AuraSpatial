//
//  LocalCommunityStore.swift
//  AuraSpatial
//
//  Midterm implementation of CommunityRepository: a bundled sample feed
//  (FR-5.1) matching the four demo soundscapes in the Figma prototype.
//
//  Bug fixes: "Industrial Loft" had 7 nodes, but the Canvas only allows 6,
//  so forking it broke the limit. Node positions were also random on
//  every launch; each sample is now a fixed, hand-designed arrangement
//  with fixed ids, so the mini-map and audio preview are always the same.
//

import Foundation

final class LocalCommunityStore: CommunityRepository {
    var supportsSharing: Bool { false }

    /// The samples, with the user's own likes added (likes are only kept
    /// on this device when there's no cloud backend).
    func fetchFeed() async throws -> [Soundscape] {
        let liked = LikesStore().load()
        return Self.feed.map { sample in
            var copy = sample
            if liked.contains(copy.id) { copy.likeCount += 1 }
            return copy
        }
    }

    func publish(_ soundscape: Soundscape, as username: String) async throws {
        throw AuthError.invalidInput("Sharing needs Firebase. See FIREBASE_SETUP.md.")
    }

    func changeLikes(of id: UUID, by delta: Int) async { }

    func recordFork(of id: UUID) async { }

    static func isSample(_ id: UUID) -> Bool {
        feed.contains { $0.id == id }
    }

    private typealias Placement = (sound: String, x: Double, y: Double)

    private static let feed: [Soundscape] = [
        sample(
            id: "C0FFEE00-0001-4A00-8000-000000000001",
            name: "Jungle Immersion",
            creator: "mara_sounds",
            likes: 234,
            forks: 41,
            placements: [
                ("Rain", 0.0, -0.75),
                ("Night Crickets", -0.55, -0.35),
                ("Wind Chimes", 0.6, -0.3),
                ("Distant Thunder", 0.0, 0.85),
                ("Ocean Waves", -0.7, 0.45),
                ("Campfire", 0.45, 0.4)
            ]
        ),
        sample(
            id: "C0FFEE00-0002-4A00-8000-000000000002",
            name: "Midnight Drive",
            creator: "synth_wolf",
            likes: 189,
            forks: 27,
            placements: [
                ("Rain", -0.3, -0.25),
                ("Distant Thunder", 0.75, -0.55),
                ("Wind Chimes", -0.8, 0.3),
                ("Campfire", 0.35, 0.6)
            ]
        ),
        sample(
            id: "C0FFEE00-0003-4A00-8000-000000000003",
            name: "Underwater",
            creator: "ambient_kay",
            likes: 312,
            forks: 58,
            placements: [
                ("Ocean Waves", 0.0, -0.3),
                ("Ocean Waves", 0.0, 0.35),
                ("Distant Thunder", -0.85, 0.0),
                ("Wind Chimes", 0.7, -0.6),
                ("Night Crickets", 0.65, 0.65)
            ]
        ),
        sample(
            id: "C0FFEE00-0004-4A00-8000-000000000004",
            name: "Industrial Loft",
            creator: "noisewright",
            likes: 145,
            forks: 19,
            placements: [
                ("Campfire", 0.25, -0.2),
                ("Distant Thunder", -0.6, -0.6),
                ("Rain", 0.8, -0.35),
                ("Wind Chimes", -0.35, 0.5),
                ("Night Crickets", 0.5, 0.7),
                ("Ocean Waves", -0.9, 0.1)
            ]
        )
    ]

    private static func sample(
        id: String,
        name: String,
        creator: String,
        likes: Int,
        forks: Int,
        placements: [Placement]
    ) -> Soundscape {
        let nodes: [SoundNode] = placements.compactMap { placement in
            guard let asset = SoundAsset.asset(named: placement.sound) else { return nil }
            return SoundNode(
                soundAssetID: asset.id,
                displayName: asset.name,
                x: placement.x,
                y: placement.y,
                volumeBias: 0.85
            )
        }
        return Soundscape(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            nodes: nodes,
            creatorUsername: creator,
            likeCount: likes,
            forkCount: forks
        )
    }
}
