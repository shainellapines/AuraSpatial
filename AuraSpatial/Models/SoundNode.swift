//
//  SoundNode.swift
//  AuraSpatial
//
//  One sound placed on the Spatial Canvas (FR-2.1-2.4). Position is stored
//  as a normalized offset from the listener at the origin (a unit circle:
//  distance 1.0 = the canvas's outer ring), so it survives across
//  different screen sizes.
//
//  Canvas convention: negative y is "up" on screen, which the audio
//  engine treats as IN FRONT of the listener.
//

import Foundation

struct SoundNode: Identifiable, Codable, Hashable {
    let id: UUID
    var soundAssetID: UUID
    var displayName: String
    /// Horizontal offset from the listener, in [-1, 1].
    var x: Double
    /// Vertical offset from the listener, in [-1, 1]. Negative = in front.
    var y: Double
    /// Manual gain layered on top of distance-based attenuation (0...1).
    var volumeBias: Double
    /// Manual left/right nudge layered on top of angle-based panning (-1...1).
    var panBias: Double
    var isLooping: Bool

    init(
        id: UUID = UUID(),
        soundAssetID: UUID,
        displayName: String,
        x: Double,
        y: Double,
        volumeBias: Double = 0.8,
        panBias: Double = 0,
        isLooping: Bool = true
    ) {
        self.id = id
        self.soundAssetID = soundAssetID
        self.displayName = displayName
        self.x = x
        self.y = y
        self.volumeBias = volumeBias
        self.panBias = panBias
        self.isLooping = isLooping
    }

    /// Distance from the listener at the origin (FR-3.1).
    var distanceFromListener: Double {
        (x * x + y * y).squareRoot()
    }

    /// Angle from the listener, in radians - drives stereo/3D panning (FR-3.2).
    var angleFromListener: Double {
        atan2(y, x)
    }
}

/// The numbers shared by the audio engine and the visuals, so what the
/// Canvas shows always matches what the engine actually does.
enum SpatialMath {
    /// One normalized canvas unit = this many meters in the 3D scene.
    static let metersPerUnit: Double = 8
    /// How far (in canvas units) a full Pan nudge shifts a sound sideways.
    static let panSpread: Double = 0.6

    /// The gain AVAudioEnvironmentNode's inverse-distance model applies
    /// (reference distance 1 m, rolloff 1): 1 / meters, capped at 1.
    static func distanceGain(forUnits units: Double) -> Double {
        let meters = max(units * metersPerUnit, 1)
        return 1 / meters
    }
}

extension SoundNode {
    /// Distance in meters as the audio engine places it.
    var meters: Double {
        distanceFromListener * SpatialMath.metersPerUnit
    }

    var zone: DistanceZone {
        DistanceZone(distance: distanceFromListener)
    }

    /// How loud this sound actually reaches the listener (0...1): the
    /// Mixer volume times distance attenuation.
    var perceivedLevel: Double {
        volumeBias * SpatialMath.distanceGain(forUnits: distanceFromListener)
    }

    /// "Front-left", "Right", "Back"... relative to the listener.
    var directionLabel: String {
        guard distanceFromListener > 0.08 else { return "Centered" }
        var bearing = atan2(x, -y) * 180 / .pi
        if bearing < 0 { bearing += 360 }
        let labels = ["Front", "Front-right", "Right", "Back-right", "Back", "Back-left", "Left", "Front-left"]
        let index = Int((bearing + 22.5) / 45) % labels.count
        return labels[index]
    }

    /// The same node pulled back inside the outer ring if it was outside.
    func clampedToUnitCircle() -> SoundNode {
        let distance = distanceFromListener
        guard distance > 1 else { return self }
        var copy = self
        copy.x = x / distance
        copy.y = y / distance
        return copy
    }
}
