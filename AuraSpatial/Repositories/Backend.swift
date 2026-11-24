//
//  Backend.swift
//  AuraSpatial
//
//  Chooses where data lives, once, at launch:
//
//  - Firebase (Auth + Cloud Firestore) when the Firebase SDK is linked AND
//    GoogleService-Info.plist is in the app. Accounts, saved layouts and
//    the Community Feed are then stored in the cloud.
//  - On-device storage otherwise (UserDefaults + a JSON file), exactly as
//    in the midterm.
//
//  Every Firebase file is wrapped in `#if canImport(...)`, so the project
//  still builds and runs before the Firebase package is added. Controllers
//  ask this file for a repository and never know which one they got - the
//  repository pattern from the SRS (Section 2.6).
//

import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif

enum Backend {
    /// True once Firebase has been configured for this launch.
    private(set) static var isCloud = false

    /// Call before any Controller is created (AuraSpatialApp.init).
    static func configure() {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            print("ℹ️ GoogleService-Info.plist not found - using on-device storage.")
            return
        }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        isCloud = true
        #endif
    }

    static func makeAuthRepository() -> AuthRepository {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        if isCloud { return FirebaseAuthStore() }
        #endif
        return LocalAuthStore()
    }

    static func makeSoundscapeRepository() -> SoundscapeRepository {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        if isCloud { return FirestoreSoundscapeStore() }
        #endif
        return LocalSoundscapeStore()
    }

    static func makeCommunityRepository() -> CommunityRepository {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        if isCloud { return FirestoreCommunityStore() }
        #endif
        return LocalCommunityStore()
    }

    /// Shown on the Profile screen.
    static var storageTitle: String {
        isCloud ? "Synced with Firebase" : "Stored on this device"
    }

    static var storageDetail: String {
        isCloud
            ? "Your account, saved layouts, and shared soundscapes are stored in Cloud Firestore and follow you to any device. Stats and settings stay on this phone."
            : "Your account, saved layouts, stats, and settings stay on this phone. Add Firebase to sync them to the cloud."
    }

    static var engineLabel: String {
        isCloud ? "Firebase Auth · Firestore" : "On-device (JSON)"
    }
}
