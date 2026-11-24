//
//  ToneGenerator.swift
//  AuraSpatial
//
//  Synthesizes seamlessly-loopable MONO audio buffers on-device, so the
//  app needs no bundled or downloaded sound files (FR-3.3).
//
//  Each texture is a small recipe instead of a plain test tone:
//    rain      - softened noise plus occasional droplets
//    ocean     - deep noise under one slow swell per loop
//    thunder   - a distant rumble with a sharp attack and long decay
//    chimes    - six bell strikes with an inharmonic overtone
//    fire      - a warm bed with random crackles
//    crickets  - two insects chirping in different rhythms
//
//  Every recipe repeats exactly once per loop, and the last quarter-second
//  is crossfaded into the start, so the loop point doesn't click.
//

import AVFAudio
import Foundation

enum ToneGenerator {
    static func buffer(for asset: SoundAsset, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * asset.texture.loopDuration)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channels = buffer.floatChannelData else {
            return nil
        }
        buffer.frameLength = frameCount

        let frames = Int(frameCount)
        var samples = loopable(
            render(asset.texture, frames: frames, sampleRate: Float(sampleRate), seed: seed(for: asset.name)),
            frames: frames,
            fadeLength: Int(sampleRate * 0.25)
        )
        normalize(&samples, peak: loudness(for: asset.texture))

        for channel in 0..<Int(format.channelCount) {
            let data = channels[channel]
            for index in 0..<frames {
                data[index] = samples[index]
            }
        }
        return buffer
    }

    // MARK: - Recipes

    /// Renders `frames` samples plus a quarter-second tail used for the
    /// loop crossfade.
    private static func render(_ texture: SoundTexture, frames: Int, sampleRate: Float, seed: UInt32) -> [Float] {
        var noise = NoiseSource(state: seed)
        let total = frames + Int(sampleRate * 0.25)
        let loopLength = Float(frames) / sampleRate
        var output = [Float](repeating: 0, count: total)

        var low: Float = 0
        var high: Float = 0
        var burst: Float = 0

        switch texture {
        case .rain:
            for index in 0..<total {
                let white = noise.next()
                low += 0.18 * (white - low)
                if noise.unit() < 0.0006 { burst = 0.4 + noise.unit() * 0.6 }
                burst *= 0.992
                output[index] = low * 0.9 + white * 0.25 + white * burst * 0.5
            }

        case .ocean:
            for index in 0..<total {
                let time = Float(index) / sampleRate
                let white = noise.next()
                low += 0.04 * (white - low)
                high += 0.25 * (white - high)
                let swell = 0.5 - 0.5 * cos(2 * Float.pi * time / loopLength)
                let foam = max(0, swell - 0.6) * 2.5
                output[index] = low * (0.25 + swell) + high * foam * 0.35
            }

        case .thunder:
            let strikeTime: Float = 1.5
            for index in 0..<total {
                let time = Float(index) / sampleRate
                let white = noise.next()
                low += 0.012 * (white - low)
                let phase = time.truncatingRemainder(dividingBy: loopLength)
                let envelope = phase > strikeTime
                    ? exp(-(phase - strikeTime) * 1.1)
                    : exp(-(strikeTime - phase) * 12)
                output[index] = low * (0.12 + envelope)
            }

        case .chimes:
            let strikes: [(time: Float, frequency: Float)] = [
                (0.2, 784), (1.4, 1047), (2.3, 880), (3.6, 1175), (4.4, 659), (5.3, 988)
            ]
            for index in 0..<total {
                let time = Float(index) / sampleRate
                var value: Float = 0
                for strike in strikes {
                    var elapsed = (time - strike.time).truncatingRemainder(dividingBy: loopLength)
                    if elapsed < 0 { elapsed += loopLength }
                    let envelope = exp(-elapsed * 1.8)
                    let fundamental = sin(2 * Float.pi * strike.frequency * elapsed)
                    let overtone = sin(2 * Float.pi * strike.frequency * 2.76 * elapsed)
                    value += envelope * (fundamental + 0.35 * overtone)
                }
                output[index] = value
            }

        case .fire:
            for index in 0..<total {
                let white = noise.next()
                low += 0.03 * (white - low)
                high += 0.3 * (white - high)
                if noise.unit() < 0.0009 { burst = 0.5 + noise.unit() * 0.5 }
                burst *= 0.97
                output[index] = low * 1.2 + (white - high) * burst * 0.8
            }

        case .crickets:
            for index in 0..<total {
                let time = Float(index) / sampleRate
                let white = noise.next()
                low += 0.02 * (white - low)
                let first = chirp(at: time, period: 0.5, offset: 0, carrier: 4400)
                let second = chirp(at: time, period: 0.8, offset: 0.2, carrier: 4700) * 0.55
                output[index] = first + second + low * 0.3
            }
        }
        return output
    }

    /// Three quick syllables every `period` seconds on a high carrier.
    private static func chirp(at time: Float, period: Float, offset: Float, carrier: Float) -> Float {
        var local = (time - offset).truncatingRemainder(dividingBy: period)
        if local < 0 { local += period }
        guard local < 0.1 else { return 0 }
        let gate = 0.5 - 0.5 * cos(2 * Float.pi * 30 * local)
        return sin(2 * Float.pi * carrier * time) * gate
    }

    // MARK: - Helpers

    /// Crossfades the rendered tail into the start so the loop is seamless.
    private static func loopable(_ rendered: [Float], frames: Int, fadeLength: Int) -> [Float] {
        var result = Array(rendered.prefix(frames))
        let fade = min(fadeLength, frames, rendered.count - frames)
        guard fade > 0 else { return result }
        for index in 0..<fade {
            let weight = Float(index) / Float(fade)
            result[index] = rendered[index] * weight + rendered[frames + index] * (1 - weight)
        }
        return result
    }

    private static func normalize(_ samples: inout [Float], peak target: Float) {
        var peak: Float = 0
        for sample in samples {
            peak = max(peak, abs(sample))
        }
        guard peak > 0 else { return }
        let scale = target / peak
        for index in samples.indices {
            samples[index] *= scale
        }
    }

    private static func loudness(for texture: SoundTexture) -> Float {
        switch texture {
        case .rain: 0.30
        case .ocean: 0.40
        case .thunder: 0.45
        case .chimes: 0.25
        case .fire: 0.35
        case .crickets: 0.18
        }
    }

    /// A stable seed per sound (FNV-1a hash of the name).
    private static func seed(for name: String) -> UInt32 {
        var hash: UInt32 = 2_166_136_261
        for byte in name.utf8 {
            hash = (hash ^ UInt32(byte)) &* 16_777_619
        }
        return hash
    }
}

/// A tiny, fast pseudo-random generator - Float.random per sample is too
/// slow for hundreds of thousands of samples.
private struct NoiseSource {
    var state: UInt32

    /// 0 ..< 1
    mutating func unit() -> Float {
        state = state &* 1_664_525 &+ 1_013_904_223
        return Float(state >> 8) / 16_777_216
    }

    /// -1 ..< 1
    mutating func next() -> Float {
        unit() * 2 - 1
    }
}
