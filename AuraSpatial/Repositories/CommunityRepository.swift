//
//  CommunityRepository.swift
//  AuraSpatial
//
//  Abstracts the Community Feed's data source. LocalCommunityStore returns
//  bundled sample soundscapes (FR-5.1); FirestoreCommunityStore reads and
//  writes a live, shared Firestore collection (FR-5.3).
//

import Foundation

protocol CommunityRepository {
    /// Whether layouts can be shared to other users (cloud only).
    var supportsSharing: Bool { get }
    func fetchFeed() async throws -> [Soundscape]
    func publish(_ soundscape: Soundscape, as username: String) async throws
    func changeLikes(of id: UUID, by delta: Int) async
    func recordFork(of id: UUID) async
}
