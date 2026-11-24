//
//  UsageStats.swift
//  AuraSpatial
//
//  Lifetime listening numbers shown on the Profile screen. Recorded by
//  CanvasController as the user actually listens - nothing is estimated.
//

import Foundation

struct UsageStats: Codable, Equatable {
    /// Seconds of audible Canvas playback (paused or muted time isn't counted).
    var listeningSeconds: Double = 0
    /// Every sound ever added from the Sound Library.
    var soundsPlaced: Int = 0
    var focusSessionsCompleted: Int = 0
    var sleepSessionsCompleted: Int = 0
    /// Placements per category, keyed by SoundCategory.rawValue.
    var categoryPlacements: [String: Int] = [:]

    var sessionsCompleted: Int {
        focusSessionsCompleted + sleepSessionsCompleted
    }

    func placements(for category: SoundCategory) -> Int {
        categoryPlacements[category.rawValue] ?? 0
    }

    var favoriteCategory: SoundCategory? {
        let total = SoundCategory.allCases.reduce(0) { $0 + placements(for: $1) }
        guard total > 0 else { return nil }
        return SoundCategory.allCases.max { placements(for: $0) < placements(for: $1) }
    }
}
