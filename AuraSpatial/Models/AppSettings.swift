//
//  AppSettings.swift
//  AuraSpatial
//
//  Every user-adjustable preference shown on the Profile screen. Decoding
//  falls back to the default for any missing key, so adding a new setting
//  later never wipes the user's existing ones.
//

import Foundation

struct AppSettings: Codable, Equatable {
    var masterVolume: Double
    var spatialMode: SpatialRenderMode
    var hapticsEnabled: Bool
    var showSoundWaves: Bool
    var showDistanceGuides: Bool
    var orbitSpeed: OrbitSpeed
    var defaultTimerMinutes: Int
    var fadeOutSeconds: Int
    var notificationsEnabled: Bool

    #if DEBUG
    /// Debug builds add a 1-minute preset so the timer and its
    /// notification can be shown in a class demo without a long wait.
    static let timerChoices = [1, 5, 10, 15, 30, 45, 60, 90]
    #else
    static let timerChoices = [5, 10, 15, 30, 45, 60, 90]
    #endif
    static let fadeChoices = [10, 30, 60]

    init() {
        masterVolume = 0.9
        spatialMode = .platformDefault
        hapticsEnabled = true
        showSoundWaves = true
        showDistanceGuides = true
        orbitSpeed = .medium
        defaultTimerMinutes = 30
        fadeOutSeconds = 30
        notificationsEnabled = true
    }

    enum CodingKeys: String, CodingKey {
        case masterVolume
        case spatialMode
        case hapticsEnabled
        case showSoundWaves
        case showDistanceGuides
        case orbitSpeed
        case defaultTimerMinutes
        case fadeOutSeconds
        case notificationsEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        masterVolume = try container.decodeIfPresent(Double.self, forKey: .masterVolume) ?? defaults.masterVolume
        spatialMode = try container.decodeIfPresent(SpatialRenderMode.self, forKey: .spatialMode) ?? defaults.spatialMode
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? defaults.hapticsEnabled
        showSoundWaves = try container.decodeIfPresent(Bool.self, forKey: .showSoundWaves) ?? defaults.showSoundWaves
        showDistanceGuides = try container.decodeIfPresent(Bool.self, forKey: .showDistanceGuides) ?? defaults.showDistanceGuides
        orbitSpeed = try container.decodeIfPresent(OrbitSpeed.self, forKey: .orbitSpeed) ?? defaults.orbitSpeed
        defaultTimerMinutes = try container.decodeIfPresent(Int.self, forKey: .defaultTimerMinutes) ?? defaults.defaultTimerMinutes
        fadeOutSeconds = try container.decodeIfPresent(Int.self, forKey: .fadeOutSeconds) ?? defaults.fadeOutSeconds
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? defaults.notificationsEnabled
    }
}
