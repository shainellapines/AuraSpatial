//
//  SavedLayoutsController.swift
//  AuraSpatial
//
//  The Controller for Saved Layouts (SRS Section 3.4): save, recall,
//  overwrite, delete (FR-4.1, FR-4.2). Every mutation goes through
//  SoundscapeRepository and then re-fetches, so what the View displays is
//  always the actually-persisted state - never local-only render state.
//

import Foundation
import Observation

@Observable
final class SavedLayoutsController {
    private(set) var savedLayouts: [Soundscape] = []
    var errorMessage: String?

    private let repository: SoundscapeRepository

    init(repository: SoundscapeRepository? = nil) {
        self.repository = repository ?? Backend.makeSoundscapeRepository()
    }

    func refresh() async {
        do {
            savedLayouts = try await repository.fetchAll()
                .map { $0.repairingAssetIDs() }
                .sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Total sounds across every saved layout (shown on the Profile).
    var totalSavedSounds: Int {
        savedLayouts.reduce(0) { $0 + $1.nodes.count }
    }

    /// A saved layout with this exact name (ignoring case), if any.
    func layout(named name: String) -> Soundscape? {
        let target = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return savedLayouts.first { $0.name.lowercased() == target }
    }

    /// "Rainy Night" -> "Rainy Night 2" (or 3, 4...) if the name is taken.
    func uniqueName(from base: String) -> String {
        guard layout(named: base) != nil else { return base }
        var number = 2
        while layout(named: "\(base) \(number)") != nil {
            number += 1
        }
        return "\(base) \(number)"
    }

    /// Saves the Canvas's current nodes as a new named layout.
    @discardableResult
    func saveNewLayout(name: String, nodes: [SoundNode]) async -> Soundscape {
        let soundscape = Soundscape(name: name, nodes: nodes)
        await persist(soundscape)
        return soundscape
    }

    /// Overwrites an existing saved layout with the Canvas's current nodes.
    @discardableResult
    func overwrite(_ soundscape: Soundscape, with nodes: [SoundNode]) async -> Soundscape {
        var updated = soundscape
        updated.nodes = nodes
        updated.updatedAt = Date()
        await persist(updated)
        return updated
    }

    /// Adds a forked community soundscape to this user's own saved
    /// layouts (FR-5.2), under a unique name.
    @discardableResult
    func fork(_ communitySoundscape: Soundscape) async -> Soundscape {
        var forked = communitySoundscape.fork()
        forked.name = uniqueName(from: communitySoundscape.name)
        await persist(forked)
        return forked
    }

    func delete(_ soundscape: Soundscape) async {
        do {
            try await repository.delete(id: soundscape.id)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Removes every saved layout (Profile > Data).
    func deleteAll() async {
        for layout in savedLayouts {
            try? await repository.delete(id: layout.id)
        }
        await refresh()
    }

    private func persist(_ soundscape: Soundscape) async {
        do {
            try await repository.save(soundscape)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
