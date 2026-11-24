//
//  CanvasController.swift
//  AuraSpatial
//
//  The Controller for the Spatial Canvas (SRS Section 3.4): owns the active
//  node list, selection, playback state (pause, Orbit mode, the session
//  timer) and lifetime listening stats, and drives SpatialAudioEngine in
//  response (FR-2.1-2.4, FR-3.1-3.3).
//
//  One lightweight "ticker" loop runs on the main actor: it advances Orbit
//  mode, fades the sound out near the end of a session timer, and counts
//  audible listening time for the Profile stats.
//

import Foundation
import Observation
import CoreGraphics

@MainActor
@Observable
final class CanvasController {
    static let maxNodes = 6

    private(set) var nodes: [SoundNode] = []
    var selectedNodeID: UUID?

    /// The saved layout currently on the Canvas, if it came from one.
    private(set) var loadedLayoutID: UUID?
    private(set) var loadedLayoutName: String?

    /// One-shot (Loop off) sounds that have finished playing.
    private(set) var finishedNodeIDs: Set<UUID> = []
    private(set) var isPaused = false
    private(set) var isOrbiting = false
    /// True while a Community preview is playing, so the two don't overlap.
    private(set) var isDucked = false
    private(set) var activeTimer: SessionTimer?
    /// Set when a timer finishes, to show a "session complete" banner.
    private(set) var completedTimerMode: SessionMode?
    private(set) var stats: UsageStats

    private let audioEngine: SpatialAudioEngine
    private let statsStore: UsageStatsStore
    private let notifier: SessionNotifier
    @ObservationIgnored private var settings = AppSettings()
    @ObservationIgnored private var appliedSpatialMode: SpatialRenderMode?
    @ObservationIgnored private var fadeMultiplier: Double = 1
    @ObservationIgnored private var draggingNodeID: UUID?
    @ObservationIgnored private var lastTick = Date()
    @ObservationIgnored private var unsavedListeningSeconds: Double = 0
    @ObservationIgnored private var oneShotTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var tickerTask: Task<Void, Never>?

    var canAddNode: Bool { nodes.count < Self.maxNodes }

    /// Asset ids currently on the Canvas - the Sound Library marks these.
    var placedAssetIDs: Set<UUID> { Set(nodes.map(\.soundAssetID)) }

    // Dependencies are built inside the init body (not as default
    // argument values): default arguments are evaluated outside the
    // main actor, so they can't construct main-actor types.
    init(audioEngine: SpatialAudioEngine? = nil, statsStore: UsageStatsStore? = nil, notifier: SessionNotifier? = nil) {
        let store = statsStore ?? UsageStatsStore()
        self.audioEngine = audioEngine ?? SpatialAudioEngine()
        self.statsStore = store
        self.notifier = notifier ?? SessionNotifier()
        self.stats = store.load()
        startTicker()
    }

    // MARK: - Placing and moving

    /// Adds a node from the Sound Library in the most open direction
    /// around the listener, then starts it playing (FR-2.3).
    func addNode(from asset: SoundAsset) {
        guard canAddNode else { return }
        let angle = openAngle()
        let node = SoundNode(
            soundAssetID: asset.id,
            displayName: asset.name,
            x: 0.55 * cos(angle),
            y: 0.55 * sin(angle)
        )
        nodes.append(node)
        audioEngine.addNode(node, asset: asset)
        selectedNodeID = node.id

        stats.soundsPlaced += 1
        stats.categoryPlacements[asset.category.rawValue, default: 0] += 1
        statsStore.save(stats)

        if isPaused { resume() }
    }

    func beginDrag(id: UUID) {
        draggingNodeID = id
    }

    func endDrag() {
        draggingNodeID = nil
    }

    /// Called continuously while a node is dragged (FR-2.4). `center` and
    /// `radius` are the listener position and outer-ring radius on screen,
    /// so the node stays exactly under the finger.
    func moveNode(id: UUID, to point: CGPoint, center: CGPoint, radius: CGFloat) {
        guard radius > 0, let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        var normalizedX = Double((point.x - center.x) / radius)
        var normalizedY = Double((point.y - center.y) / radius)
        let distance = (normalizedX * normalizedX + normalizedY * normalizedY).squareRoot()
        if distance > 1 {
            normalizedX /= distance
            normalizedY /= distance
        }
        nodes[index].x = normalizedX
        nodes[index].y = normalizedY
        audioEngine.updatePosition(for: nodes[index])
    }

    // MARK: - Mixer

    func setVolume(_ volume: Double, for id: UUID) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[index].volumeBias = clamp(volume, to: 0...1)
        audioEngine.setVolume(nodes[index].volumeBias, for: id)
    }

    func setPan(_ pan: Double, for id: UUID) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[index].panBias = clamp(pan, to: -1...1)
        audioEngine.updatePosition(for: nodes[index])
    }

    func setLooping(_ isLooping: Bool, for id: UUID) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        guard nodes[index].isLooping != isLooping else { return }
        nodes[index].isLooping = isLooping
        replay(id: id)
    }

    /// Restarts a node's sound - "Play again" for a one-shot.
    func replay(id: UUID) {
        guard let node = node(with: id) else { return }
        oneShotTasks[id]?.cancel()
        oneShotTasks[id] = nil
        finishedNodeIDs.remove(id)
        audioEngine.restart(node)
        scheduleOneShotEnd(for: node)
        if isPaused { resume() }
    }

    // MARK: - Removing and loading

    func removeNode(id: UUID) {
        nodes.removeAll { $0.id == id }
        audioEngine.removeNode(id: id)
        oneShotTasks[id]?.cancel()
        oneShotTasks[id] = nil
        finishedNodeIDs.remove(id)
        if selectedNodeID == id { selectedNodeID = nil }
    }

    /// Removes all nodes and stops all audio - a fresh restart.
    func clearAll() {
        cancelTimer()
        audioEngine.removeAllNodes()
        cancelOneShots()
        nodes.removeAll()
        selectedNodeID = nil
        loadedLayoutID = nil
        loadedLayoutName = nil
    }

    /// Replaces the whole canvas with a saved or forked layout's nodes.
    func loadLayout(_ soundscape: Soundscape) {
        audioEngine.removeAllNodes()
        cancelOneShots()
        let repaired = soundscape.repairingAssetIDs()
        nodes = Array(repaired.nodes.prefix(Self.maxNodes)).map { $0.clampedToUnitCircle() }
        selectedNodeID = nil
        loadedLayoutID = soundscape.id
        loadedLayoutName = soundscape.name
        for node in nodes {
            if let asset = SoundAsset.resolve(node) {
                audioEngine.addNode(node, asset: asset)
                scheduleOneShotEnd(for: node)
            }
        }
        if isPaused { resume() }
    }

    /// Records that the Canvas now matches a just-saved layout.
    func markSaved(as soundscape: Soundscape) {
        loadedLayoutID = soundscape.id
        loadedLayoutName = soundscape.name
    }

    func node(with id: UUID?) -> SoundNode? {
        guard let id else { return nil }
        return nodes.first { $0.id == id }
    }

    /// Whether a node is audible right now (not paused, not a finished
    /// one-shot, not muted by a Community preview).
    func isSounding(_ node: SoundNode) -> Bool {
        !isPaused && !isDucked && !finishedNodeIDs.contains(node.id)
    }

    // MARK: - Playback controls

    func togglePause() {
        guard !nodes.isEmpty else { return }
        if isPaused { resume() } else { pause() }
    }

    func toggleOrbit() {
        isOrbiting.toggle()
    }

    func startTimer(mode: SessionMode, minutes: Int) {
        let timer = SessionTimer(mode: mode, duration: TimeInterval(minutes * 60), startDate: Date())
        activeTimer = timer
        completedTimerMode = nil
        fadeMultiplier = 1
        applyMasterVolume()
        if isPaused { resume() }
        scheduleNotification(for: timer)
    }

    func cancelTimer() {
        notifier.cancelSessionEnd()
        activeTimer = nil
        fadeMultiplier = 1
        applyMasterVolume()
    }

    func dismissCompletedBanner() {
        completedTimerMode = nil
    }

    /// Mutes the Canvas while a Community preview plays.
    func setDucked(_ ducked: Bool) {
        guard isDucked != ducked else { return }
        isDucked = ducked
        applyMasterVolume()
    }

    /// Applies the Profile screen's settings to the audio engine.
    func apply(_ newSettings: AppSettings) {
        let notificationsChanged = settings.notificationsEnabled != newSettings.notificationsEnabled
        settings = newSettings
        if notificationsChanged, let timer = activeTimer {
            if newSettings.notificationsEnabled {
                scheduleNotification(for: timer)
            } else {
                notifier.cancelSessionEnd()
            }
        }
        if appliedSpatialMode != newSettings.spatialMode {
            audioEngine.setSpatialMode(newSettings.spatialMode)
            appliedSpatialMode = newSettings.spatialMode
        }
        applyMasterVolume()
    }

    func resetStats() {
        stats = UsageStats()
        unsavedListeningSeconds = 0
        statsStore.save(stats)
    }

    // MARK: - Private

    private func pause() {
        isPaused = true
        audioEngine.pauseAll()
    }

    private func resume() {
        isPaused = false
        completedTimerMode = nil
        audioEngine.resumeAll()
    }

    /// Schedules the "session complete" notification. If the timer was
    /// cancelled or replaced while the permission prompt was up, the
    /// notification is removed again.
    private func scheduleNotification(for timer: SessionTimer) {
        guard settings.notificationsEnabled else { return }
        Task { [weak self] in
            guard let self else { return }
            await self.notifier.scheduleSessionEnd(for: timer)
            if self.activeTimer != timer {
                self.notifier.cancelSessionEnd()
            }
        }
    }

    private func applyMasterVolume() {
        let volume = isDucked ? 0 : settings.masterVolume * fadeMultiplier
        audioEngine.setMasterVolume(volume)
    }

    /// For a Loop-off node, marks it finished after one pass.
    private func scheduleOneShotEnd(for node: SoundNode) {
        guard !node.isLooping else { return }
        let id = node.id
        let seconds = audioEngine.loopLength(for: id)
        guard seconds > 0 else { return }
        oneShotTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self else { return }
            self.finishedNodeIDs.insert(id)
            self.oneShotTasks[id] = nil
        }
    }

    private func cancelOneShots() {
        for task in oneShotTasks.values {
            task.cancel()
        }
        oneShotTasks.removeAll()
        finishedNodeIDs.removeAll()
    }

    /// The slot (one of six directions) farthest from existing sounds.
    private func openAngle() -> Double {
        let step = 2 * Double.pi / Double(Self.maxNodes)
        let candidates: [Double] = (0..<Self.maxNodes).map { Double($0) * step - Double.pi / 2 }
        let existing: [Double] = nodes.map(\.angleFromListener)
        guard !existing.isEmpty else { return candidates[0] }
        var bestAngle = candidates[0]
        var bestGap = -1.0
        for candidate in candidates {
            var gap = Double.pi
            for other in existing {
                let difference = abs(atan2(sin(candidate - other), cos(candidate - other)))
                gap = min(gap, difference)
            }
            if gap > bestGap {
                bestGap = gap
                bestAngle = candidate
            }
        }
        return bestAngle
    }

    private func startTicker() {
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                let interval = self?.tickInterval ?? 0.25
                try? await Task.sleep(for: .seconds(interval))
                guard let self else { return }
                self.tick()
            }
        }
    }

    /// Fast while Orbit is moving sounds, slow otherwise.
    private var tickInterval: Double {
        isOrbiting && !isPaused && !nodes.isEmpty ? 1.0 / 30.0 : 0.25
    }

    private func tick() {
        let now = Date()
        let elapsed = min(now.timeIntervalSince(lastTick), 0.5)
        lastTick = now

        if isOrbiting && !isPaused && !nodes.isEmpty {
            advanceOrbit(by: elapsed)
        }
        if let timer = activeTimer {
            updateTimer(timer, now: now)
        }
        if !nodes.isEmpty && !isPaused && !isDucked {
            recordListening(elapsed)
        }
    }

    private func advanceOrbit(by elapsed: Double) {
        let angle = settings.orbitSpeed.radiansPerSecond * elapsed
        let cosine = cos(angle)
        let sine = sin(angle)
        var updated = nodes
        for index in updated.indices where updated[index].id != draggingNodeID {
            let x = updated[index].x
            let y = updated[index].y
            updated[index].x = x * cosine - y * sine
            updated[index].y = x * sine + y * cosine
        }
        nodes = updated
        for node in updated {
            audioEngine.updatePosition(for: node)
        }
    }

    private func updateTimer(_ timer: SessionTimer, now: Date) {
        let remaining = timer.remaining(at: now)
        guard remaining > 0 else {
            finishTimer(timer)
            return
        }
        let fadeLength = Double(max(settings.fadeOutSeconds, 1))
        let multiplier = remaining < fadeLength ? remaining / fadeLength : 1
        if abs(multiplier - fadeMultiplier) > 0.005 {
            fadeMultiplier = multiplier
            applyMasterVolume()
        }
    }

    private func finishTimer(_ timer: SessionTimer) {
        activeTimer = nil
        if !nodes.isEmpty { pause() }
        fadeMultiplier = 1
        applyMasterVolume()
        switch timer.mode {
        case .focus: stats.focusSessionsCompleted += 1
        case .sleep: stats.sleepSessionsCompleted += 1
        }
        statsStore.save(stats)
        completedTimerMode = timer.mode
    }

    private func recordListening(_ seconds: Double) {
        unsavedListeningSeconds += seconds
        guard unsavedListeningSeconds >= 5 else { return }
        stats.listeningSeconds += unsavedListeningSeconds
        unsavedListeningSeconds = 0
        statsStore.save(stats)
    }

    private func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
