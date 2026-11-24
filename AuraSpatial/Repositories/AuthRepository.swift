//
//  AuthRepository.swift
//  AuraSpatial
//
//  Abstracts sign-up / log-in / profile edits. LocalAuthStore keeps
//  accounts on-device (FR-1.1); FirebaseAuthStore uses Firebase Auth +
//  Firestore (FR-1.2). Backend.swift picks one at launch.
//

import Foundation

protocol AuthRepository {
    func currentUser() async -> UserProfile?
    func signUp(username: String, email: String, password: String) async throws -> UserProfile
    func logIn(email: String, password: String) async throws -> UserProfile
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile
    func deleteAccount(_ profile: UserProfile) async throws
    func logOut() async
    /// Emails a password-reset link (Firebase only).
    func sendPasswordReset(email: String) async throws
    /// Checks the current password, then replaces it.
    func changePassword(current: String, new newPassword: String) async throws
}

enum AuthError: LocalizedError {
    case invalidCredentials
    case missingFields
    case emailInUse
    case accountNotFound
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: "That password doesn't match this account."
        case .missingFields: "Fill in every field to continue."
        case .emailInUse: "An account with that email already exists. Log in instead."
        case .accountNotFound: "No account uses that email yet. Sign up first."
        case .invalidInput(let message): message
        }
    }
}
