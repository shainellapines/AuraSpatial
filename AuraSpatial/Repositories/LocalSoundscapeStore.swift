//
//  LocalSoundscapeStore.swift
//  AuraSpatial
//
//  Midterm implementation of SoundscapeRepository: one JSON file in the
//  app's Documents directory (SRS Section 4.1). Every write re-reads,
//  mutates, and re-writes the whole array so overwrite/delete are always
//  reflected the next time fetchAll() is called - this is the persistence
//  guarantee the Figma prototype's "Overwrite" control was found to be
//  missing during prototype QA.
//

import Foundation

actor LocalSoundscapeStore: SoundscapeRepository {
    private let fileURL: URL
    private let fileManager: FileManager
    private var cachedData: [Soundscape]?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = documents.appendingPathComponent("saved_layouts.json")
    }

    func fetchAll() async throws -> [Soundscape] {
        // Return cached data if available
        if let cached = cachedData {
            return cached
        }
        
        // Check if file exists (fast operation)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            cachedData = Self.seedData
            return Self.seedData
        }
        
        // Read and decode (actor already ensures thread safety)
        let data = try Data(contentsOf: fileURL)
        let decoded = try JSONDecoder.auraSpatial.decode([Soundscape].self, from: data)
        cachedData = decoded
        return decoded
    }

    func save(_ soundscape: Soundscape) async throws {
        var all = try await fetchAll()
        
        if let index = all.firstIndex(where: { $0.id == soundscape.id }) {
            var updated = soundscape
            updated.updatedAt = Date()
            all[index] = updated
        } else {
            all.append(soundscape)
        }
        
        try await write(all)
        cachedData = all
    }

    func delete(id: UUID) async throws {
        var all = try await fetchAll()
        all.removeAll { $0.id == id }
        try await write(all)
        cachedData = all
    }

    private func write(_ soundscapes: [Soundscape]) async throws {
        let data = try JSONEncoder.auraSpatial.encode(soundscapes)
        // Actor already provides isolation, no need for Task.detached
        try data.write(to: fileURL, options: .atomic)
    }

    /// Bundled sample data so Saved Layouts is never empty on first launch.
    private static let seedData: [Soundscape] = [
        Soundscape(
            name: "Focus Mode",
            nodes: [
                SoundNode(soundAssetID: SoundAsset.library[1].id, displayName: "Ocean Waves", x: 0.3, y: -0.2),
                SoundNode(soundAssetID: SoundAsset.library[3].id, displayName: "Wind Chimes", x: -0.4, y: 0.5)
            ],
            updatedAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        ),
        Soundscape(
            name: "Sleep Drift",
            nodes: [
                SoundNode(soundAssetID: SoundAsset.library[0].id, displayName: "Rain", x: 0.1, y: 0.6)
            ],
            updatedAt: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        )
    ]
}

extension JSONEncoder {
    static let auraSpatial: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension JSONDecoder {
    static let auraSpatial: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
