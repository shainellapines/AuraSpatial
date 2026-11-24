//
//  SpatialAudioEngine.swift
//  AuraSpatial
//
//  Wraps AVAudioEngine + AVAudioEnvironmentNode to give every SoundNode
//  real-time distance-based attenuation and angle-based panning
//  (FR-3.1, FR-3.2), driven by procedurally generated buffers from
//  ToneGenerator (FR-3.3).
//
//  Fixes in this version:
//  - Players now connect in MONO. AVAudioEnvironmentNode only positions
//    mono sources in 3D; the old stereo connection bypassed spatialization.
//  - Canvas up/down now maps to front/back (the z axis). Before it mapped
//    to the y axis, which is height above the listener.
//  - The Mixer's Pan nudges the sound sideways, and Loop actually controls
//    whether the buffer repeats.
//  - Distance attenuation uses explicit parameters (inverse model, 1 m
//    reference) that SpatialMath mirrors, so the Canvas readout is exact.
//

import AVFAudio
import Foundation

@MainActor
final class SpatialAudioEngine {
    private let engine = AVAudioEngine()
    private let environment = AVAudioEnvironmentNode()
    private var players: [UUID: AVAudioPlayerNode] = [:]
    private var playerBuffers: [UUID: AVAudioPCMBuffer] = [:]
    private var bufferCache: [UUID: AVAudioPCMBuffer] = [:]
    private var monoFormat: AVAudioFormat?
    private var renderingAlgorithm: AVAudio3DMixingRenderingAlgorithm = .equalPowerPanning
    private var isConfigured = false
    private var isPausedAll = false

    init() {
        setupAudioSession()
        setupAudioEngine()
    }

    // MARK: - Setup

    /// `.playback` (on the Simulator too) so the soundscape keeps playing
    /// with the screen locked or the app in the background - required
    /// for Sleep sessions. Background playback also needs the "Audio"
    /// Background Mode turned on for the target in Xcode.
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("⚠️ Audio session setup: \(error.localizedDescription)")
        }
    }

    private func setupAudioEngine() {
        engine.attach(environment)

        let outputFormat = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.connect(environment, to: engine.mainMixerNode, format: outputFormat)

        let sampleRate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 44_100
        monoFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)

        environment.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environment.distanceAttenuationParameters.distanceAttenuationModel = .inverse
        environment.distanceAttenuationParameters.referenceDistance = 1
        environment.distanceAttenuationParameters.maximumDistance = 20
        environment.distanceAttenuationParameters.rolloffFactor = 1

        renderingAlgorithm = algorithm(for: SpatialRenderMode.platformDefault)

        engine.prepare()
        startEngineWithRetry()
    }

    private func startEngineWithRetry(attempt: Int = 0) {
        do {
            if !engine.isRunning {
                try engine.start()
                isConfigured = true
            }
        } catch {
            if attempt < 3 {
                let delay = UInt64(100_000_000 * (1 << attempt)) // 0.1s, 0.2s, 0.4s
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: delay)
                    startEngineWithRetry(attempt: attempt + 1)
                }
            } else {
                print("⚠️ Audio engine failed to start after \(attempt) retries: \(error.localizedDescription)")
                isConfigured = true
            }
        }
    }

    private func ensureEngineRunning() {
        if !engine.isRunning {
            engine.prepare()
            do {
                try engine.start()
                isConfigured = true
            } catch {
                print("⚠️ Failed to restart audio engine: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Nodes

    /// Adds a player for `node`'s sound and starts it (looping or once).
    func addNode(_ node: SoundNode, asset: SoundAsset) {
        ensureEngineRunning()
        guard isConfigured, let format = monoFormat else {
            print("⚠️ Audio engine not ready, skipping node addition")
            return
        }
        if players[node.id] != nil {
            removeNode(id: node.id)
        }
        guard let buffer = cachedBuffer(for: asset, format: format) else { return }

        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: environment, format: format)
        player.renderingAlgorithm = renderingAlgorithm

        players[node.id] = player
        playerBuffers[node.id] = buffer
        applyPosition(node, to: player)
        schedule(player, buffer: buffer, looping: node.isLooping)
    }

    /// Recomputes a node's 3D position from its canvas offset and Pan
    /// nudge (FR-3.1, FR-3.2).
    func updatePosition(for node: SoundNode) {
        guard let player = players[node.id] else { return }
        applyPosition(node, to: player)
    }

    func setVolume(_ volume: Double, for nodeID: UUID) {
        players[nodeID]?.volume = Float(volume)
    }

    /// Re-schedules a node's buffer - used when Loop is toggled and for
    /// "Play again" on a one-shot sound.
    func restart(_ node: SoundNode) {
        guard let player = players[node.id], let buffer = playerBuffers[node.id] else { return }
        schedule(player, buffer: buffer, looping: node.isLooping)
    }

    /// Length of one pass through a node's sound, in seconds.
    func loopLength(for nodeID: UUID) -> TimeInterval {
        guard let buffer = playerBuffers[nodeID], buffer.format.sampleRate > 0 else { return 0 }
        return Double(buffer.frameLength) / buffer.format.sampleRate
    }

    func removeNode(id: UUID) {
        guard let player = players[id] else { return }
        player.stop()
        engine.detach(player)
        players.removeValue(forKey: id)
        playerBuffers.removeValue(forKey: id)
    }

    func removeAllNodes() {
        for id in Array(players.keys) {
            removeNode(id: id)
        }
    }

    // MARK: - Whole-engine controls

    /// Pauses every sound and the engine itself, so a paused or finished
    /// session doesn't keep the app running in the background.
    func pauseAll() {
        isPausedAll = true
        for player in players.values {
            player.pause()
        }
        engine.pause()
    }

    func resumeAll() {
        isPausedAll = false
        ensureEngineRunning()
        for player in players.values {
            player.play()
        }
    }

    /// Master volume for everything this engine plays (0...1).
    func setMasterVolume(_ volume: Double) {
        environment.outputVolume = Float(min(max(volume, 0), 1))
    }

    func setSpatialMode(_ mode: SpatialRenderMode) {
        renderingAlgorithm = algorithm(for: mode)
        for player in players.values {
            player.renderingAlgorithm = renderingAlgorithm
        }
    }

    deinit {
        engine.stop()
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }

    // MARK: - Private helpers

    private func schedule(_ player: AVAudioPlayerNode, buffer: AVAudioPCMBuffer, looping: Bool) {
        player.stop()
        let options: AVAudioPlayerNodeBufferOptions = looping ? [.loops] : []
        player.scheduleBuffer(buffer, at: nil, options: options)
        if !isPausedAll {
            player.play()
        }
    }

    private func cachedBuffer(for asset: SoundAsset, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        if let cached = bufferCache[asset.id] {
            return cached
        }
        let buffer = ToneGenerator.buffer(for: asset, format: format)
        bufferCache[asset.id] = buffer
        return buffer
    }

    private func algorithm(for mode: SpatialRenderMode) -> AVAudio3DMixingRenderingAlgorithm {
        switch mode {
        case .immersive: .HRTF
        case .stereo: .equalPowerPanning
        }
    }

    /// Canvas x -> left/right, canvas y -> front/back (negative = in
    /// front, matching AVAudioEnvironmentNode's default forward of -z).
    /// Pan nudges the sound sideways on top of its real position.
    private func applyPosition(_ node: SoundNode, to player: AVAudioPlayerNode) {
        let scale = Float(SpatialMath.metersPerUnit)
        let shiftedX = node.x + node.panBias * SpatialMath.panSpread
        player.position = AVAudio3DPoint(
            x: Float(shiftedX) * scale,
            y: 0,
            z: Float(node.y) * scale
        )
        player.volume = Float(node.volumeBias)
    }
}
