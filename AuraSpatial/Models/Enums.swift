//
//  Enums.swift
//  AuraSpatial
//
//  Shared enums used across the Model layer. Kept free of any SwiftUI
//  import - color/visual mapping lives in Utilities/Theme.swift instead,
//  so this file stays pure Foundation.
//

import Foundation

/// The kind of sound ToneGenerator synthesizes on-device (FR-3.3). Each
/// texture is a small procedural recipe (filtered noise, swells, chime
/// strikes, chirps) rather than a single test tone.
enum SoundTexture: String, Codable, CaseIterable, Identifiable {
    case rain
    case ocean
    case thunder
    case chimes
    case fire
    case crickets

    var id: Self { self }

    /// Length of one seamless loop, in seconds.
    var loopDuration: Double {
        switch self {
        case .rain, .fire, .crickets: 4
        case .chimes: 6
        case .ocean, .thunder: 8
        }
    }
}

/// The three Sound Library categories shown as a small uppercase label
/// under every node/card (NATURE / AMBIENT / RHYTHM).
enum SoundCategory: String, Codable, CaseIterable, Identifiable {
    case nature = "Nature"
    case ambient = "Ambient"
    case rhythm = "Rhythm"

    var id: Self { self }

    var label: String { rawValue.uppercased() }
}

/// The three distance bands drawn as rings on the Canvas.
enum DistanceZone: String, CaseIterable, Identifiable {
    case near
    case mid
    case far

    var id: Self { self }

    var label: String { rawValue.capitalized }

    /// Outer edge of the band, in normalized canvas units (1.0 = edge).
    var outerRadius: Double {
        switch self {
        case .near: 0.4
        case .mid: 0.75
        case .far: 1.0
        }
    }

    init(distance: Double) {
        if distance < DistanceZone.near.outerRadius {
            self = .near
        } else if distance < DistanceZone.mid.outerRadius {
            self = .mid
        } else {
            self = .far
        }
    }
}

/// How the audio engine renders position: true 3D (HRTF, best with
/// headphones) or plain left/right stereo panning.
enum SpatialRenderMode: String, Codable, CaseIterable, Identifiable {
    case immersive
    case stereo

    var id: Self { self }

    var label: String {
        switch self {
        case .immersive: "3D"
        case .stereo: "Stereo"
        }
    }

    var detail: String {
        switch self {
        case .immersive: "Head-related 3D audio. Best with headphones."
        case .stereo: "Simple left/right panning. Lighter on battery."
        }
    }

    /// The Simulator has no HRTF-friendly output, so it starts on stereo.
    static var platformDefault: SpatialRenderMode {
        #if targetEnvironment(simulator)
        return .stereo
        #else
        return .immersive
        #endif
    }
}

/// How fast Orbit mode carries every sound around the listener.
enum OrbitSpeed: String, Codable, CaseIterable, Identifiable {
    case slow
    case medium
    case fast

    var id: Self { self }

    var label: String { rawValue.capitalized }

    var radiansPerSecond: Double {
        switch self {
        case .slow: 0.08
        case .medium: 0.18
        case .fast: 0.35
        }
    }
}

/// What a session timer is for. Both fade out at the end; the mode
/// changes the label, icon and which stat it counts toward.
enum SessionMode: String, Codable, CaseIterable, Identifiable {
    case focus
    case sleep

    var id: Self { self }

    var label: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .focus: "brain.head.profile"
        case .sleep: "moon.zzz.fill"
        }
    }

    var completionTitle: String {
        switch self {
        case .focus: "Focus session complete"
        case .sleep: "Sleep timer finished"
        }
    }
}

/// The accent a user picks for their profile avatar.
enum AvatarColor: String, Codable, CaseIterable, Identifiable {
    case violet
    case teal
    case amber
    case rose

    var id: Self { self }
}
