//
//  SoundAsset.swift
//  AuraSpatial
//
//  A catalog entry in the Sound Library (FR-2.3). Each asset describes how
//  to *synthesize* its loop on-device via ToneGenerator (FR-3.3), rather
//  than pointing at a bundled or downloaded audio file.
//
//  Bug fix: every asset now has a FIXED id. Before, `UUID()` generated a
//  new id on every launch, so saved layouts pointed at ids that no longer
//  existed after the app restarted - their sounds loaded silent and lost
//  their colors. `resolve(_:)` also repairs layouts saved with old ids by
//  falling back to the sound's name.
//

import Foundation

struct SoundAsset: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let systemImageName: String
    let texture: SoundTexture
    let category: SoundCategory
    /// One short line shown in the Sound Library.
    let summary: String
}

extension SoundAsset {
    /// The Sound Library catalog. Ids are fixed so saved layouts keep
    /// working across launches.
    static let library: [SoundAsset] = [
        SoundAsset(
            id: UUID(uuidString: "A0F1C3B2-0001-4C6E-9A10-5A1D00000001")!,
            name: "Rain",
            systemImageName: "cloud.rain.fill",
            texture: .rain,
            category: .nature,
            summary: "Steady rainfall with soft droplets"
        ),
        SoundAsset(
            id: UUID(uuidString: "A0F1C3B2-0002-4C6E-9A10-5A1D00000002")!,
            name: "Ocean Waves",
            systemImageName: "water.waves",
            texture: .ocean,
            category: .nature,
            summary: "Slow swells rolling in and out"
        ),
        SoundAsset(
            id: UUID(uuidString: "A0F1C3B2-0003-4C6E-9A10-5A1D00000003")!,
            name: "Distant Thunder",
            systemImageName: "cloud.bolt.fill",
            texture: .thunder,
            category: .ambient,
            summary: "A low rumble far on the horizon"
        ),
        SoundAsset(
            id: UUID(uuidString: "A0F1C3B2-0004-4C6E-9A10-5A1D00000004")!,
            name: "Wind Chimes",
            systemImageName: "wind",
            texture: .chimes,
            category: .ambient,
            summary: "Bright, unhurried bell tones"
        ),
        SoundAsset(
            id: UUID(uuidString: "A0F1C3B2-0005-4C6E-9A10-5A1D00000005")!,
            name: "Campfire",
            systemImageName: "flame.fill",
            texture: .fire,
            category: .rhythm,
            summary: "Warm crackle and pop"
        ),
        SoundAsset(
            id: UUID(uuidString: "A0F1C3B2-0006-4C6E-9A10-5A1D00000006")!,
            name: "Night Crickets",
            systemImageName: "leaf.fill",
            texture: .crickets,
            category: .nature,
            summary: "Rhythmic chirps on a summer night"
        )
    ]

    static func asset(id: UUID) -> SoundAsset? {
        library.first { $0.id == id }
    }

    static func asset(named name: String) -> SoundAsset? {
        library.first { $0.name == name }
    }

    /// Finds the asset a node plays. Falls back to the node's display name
    /// so layouts saved before ids were fixed still resolve.
    static func resolve(_ node: SoundNode) -> SoundAsset? {
        asset(id: node.soundAssetID) ?? asset(named: node.displayName)
    }
}
