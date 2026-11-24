//
//  Soundscape.swift
//  AuraSpatial
//
//  A saved arrangement of nodes (FR-4.1) - what SoundscapeRepository
//  persists, and what one Community Feed card represents.
//

import Foundation

struct Soundscape: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var nodes: [SoundNode]
    var createdAt: Date
    var updatedAt: Date

    // Community-only metadata. `nil` creatorUsername marks a purely private
    // layout that has never been shared.
    var creatorUsername: String?
    var likeCount: Int
    var forkCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        nodes: [SoundNode],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        creatorUsername: String? = nil,
        likeCount: Int = 0,
        forkCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.nodes = nodes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.creatorUsername = creatorUsername
        self.likeCount = likeCount
        self.forkCount = forkCount
    }

    /// A copy suitable for "forking" into the current user's own Saved
    /// Layouts (FR-5.2): a fresh identity, reset community metadata.
    func fork() -> Soundscape {
        Soundscape(
            name: name,
            nodes: nodes,
            createdAt: Date(),
            updatedAt: Date(),
            creatorUsername: nil,
            likeCount: 0,
            forkCount: 0
        )
    }
}

extension Soundscape {
    /// How many sounds of each category this layout contains.
    var categoryCounts: [SoundCategory: Int] {
        var counts: [SoundCategory: Int] = [:]
        for node in nodes {
            if let category = SoundAsset.resolve(node)?.category {
                counts[category, default: 0] += 1
            }
        }
        return counts
    }

    /// The category with the most sounds, used to tint cards.
    var dominantCategory: SoundCategory? {
        let counts = categoryCounts
        guard !counts.isEmpty else { return nil }
        return SoundCategory.allCases.max { (counts[$0] ?? 0) < (counts[$1] ?? 0) }
    }

    /// Rewrites every node's asset id to the current fixed id - repairs
    /// layouts saved before ids were fixed.
    func repairingAssetIDs() -> Soundscape {
        var copy = self
        copy.nodes = nodes.map { node in
            var fixed = node
            if let asset = SoundAsset.resolve(node) {
                fixed.soundAssetID = asset.id
            }
            return fixed
        }
        return copy
    }
}
