//
//  FirestoreStores.swift
//  AuraSpatial
//
//  Cloud Firestore versions of the two data repositories (SRS Section 4.2):
//
//    users/{uid}/layouts/{layoutID}   - FirestoreSoundscapeStore (private)
//    community/{soundscapeID}         - FirestoreCommunityStore (shared)
//
//  Writes go to Firestore's offline cache first and sync in the background,
//  so saving works without internet; reads fall back to the cache when
//  offline. Only compiled when the Firebase package is linked.
//

import Foundation
#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
import FirebaseAuth
import FirebaseFirestore

// MARK: - Saved layouts

final class FirestoreSoundscapeStore: SoundscapeRepository {
    private func currentUID() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw AuthError.invalidInput("Your session ended. Log in again.")
        }
        return uid
    }

    private func layouts(for uid: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(uid).collection("layouts")
    }

    func fetchAll() async throws -> [Soundscape] {
        let uid = try currentUID()
        let collection = layouts(for: uid)
        do {
            let snapshot = try await collection.getDocuments()
            let remote = snapshot.documents.compactMap { try? $0.data(as: Soundscape.self) }
            if remote.isEmpty, let uploaded = await uploadLocalLayoutsOnce(uid: uid, into: collection) {
                return uploaded
            }
            return remote
        } catch {
            throw FirebaseErrors.friendly(error)
        }
    }

    func save(_ soundscape: Soundscape) async throws {
        let uid = try currentUID()
        let data = try Firestore.Encoder().encode(soundscape)
        layouts(for: uid).document(soundscape.id.uuidString).setData(data) { error in
            if let error {
                print("⚠️ Layout sync failed: \(error.localizedDescription)")
            }
        }
    }

    func delete(id: UUID) async throws {
        let uid = try currentUID()
        layouts(for: uid).document(id.uuidString).delete { error in
            if let error {
                print("⚠️ Layout delete failed: \(error.localizedDescription)")
            }
        }
    }

    /// The first time an account opens an empty cloud library, the layouts
    /// already saved on this device are uploaded, so nothing is lost when
    /// switching from the midterm's on-device storage.
    private func uploadLocalLayoutsOnce(uid: String, into collection: CollectionReference) async -> [Soundscape]? {
        let key = "auraspatial.cloud-migrated.\(uid)"
        guard !UserDefaults.standard.bool(forKey: key) else { return nil }
        UserDefaults.standard.set(true, forKey: key)

        let local = ((try? await LocalSoundscapeStore().fetchAll()) ?? []).map { $0.repairingAssetIDs() }
        guard !local.isEmpty else { return nil }
        for layout in local {
            guard let data = try? Firestore.Encoder().encode(layout) else { continue }
            collection.document(layout.id.uuidString).setData(data) { _ in }
        }
        return local
    }
}

// MARK: - Community feed

final class FirestoreCommunityStore: CommunityRepository {
    private var community: CollectionReference {
        Firestore.firestore().collection("community")
    }

    var supportsSharing: Bool { true }

    /// Soundscapes people shared (most-liked first), followed by the
    /// bundled samples so the feed is never empty.
    func fetchFeed() async throws -> [Soundscape] {
        let samples = (try? await LocalCommunityStore().fetchFeed()) ?? []
        do {
            let snapshot = try await community
                .order(by: "likeCount", descending: true)
                .limit(to: 50)
                .getDocuments()
            let shared = snapshot.documents.compactMap { try? $0.data(as: Soundscape.self) }
            let sharedIDs = Set(shared.map(\.id))
            return shared + samples.filter { !sharedIDs.contains($0.id) }
        } catch {
            return samples
        }
    }

    /// Shares (or re-shares) a saved layout. The document id is the
    /// layout's id, so sharing it again updates the same post and keeps
    /// its likes and forks.
    func publish(_ soundscape: Soundscape, as username: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw AuthError.invalidInput("Your session ended. Log in again.")
        }
        let reference = community.document(soundscape.id.uuidString)
        do {
            var data = try Firestore.Encoder().encode(soundscape.repairingAssetIDs())
            data["creatorUsername"] = username
            data["creatorUID"] = uid
            data["updatedAt"] = Timestamp(date: Date())

            let existing = try await reference.getDocument()
            if existing.exists {
                data.removeValue(forKey: "likeCount")
                data.removeValue(forKey: "forkCount")
                data.removeValue(forKey: "createdAt")
                try await reference.updateData(data)
            } else {
                data["likeCount"] = 0
                data["forkCount"] = 0
                try await reference.setData(data)
            }
        } catch {
            throw FirebaseErrors.friendly(error)
        }
    }

    /// `FieldValue.increment` adds on the server, so two people liking at
    /// the same moment are both counted.
    func changeLikes(of id: UUID, by delta: Int) async {
        guard !LocalCommunityStore.isSample(id) else { return }
        community.document(id.uuidString).updateData(["likeCount": FieldValue.increment(Int64(delta))]) { _ in }
    }

    func recordFork(of id: UUID) async {
        guard !LocalCommunityStore.isSample(id) else { return }
        community.document(id.uuidString).updateData(["forkCount": FieldValue.increment(Int64(1))]) { _ in }
    }
}
#endif
