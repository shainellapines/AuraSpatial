//
//  AuthController.swift
//  AuraSpatial
//
//  The Controller for auth state (SRS Section 3.4's MVC adaptation): owns
//  the session and exposes it to every View via the environment. Uses the
//  Observation framework's @Observable (iOS 17+) rather than the older
//  ObservableObject/@Published pattern.
//

import Foundation
import Observation

@Observable
final class AuthController {
    private(set) var currentUser: UserProfile?
    var errorMessage: String?

    private let repository: AuthRepository

    var isSignedIn: Bool { currentUser != nil }

    init(repository: AuthRepository? = nil) {
        self.repository = repository ?? Backend.makeAuthRepository()
    }

    func restoreSession() async {
        currentUser = await repository.currentUser()
    }

    func signUp(username: String, email: String, password: String) async {
        do {
            errorMessage = nil
            currentUser = try await repository.signUp(username: username, email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logIn(email: String, password: String) async {
        do {
            errorMessage = nil
            currentUser = try await repository.logIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Saves edits from the Edit Profile screen. Returns true on success.
    @discardableResult
    func updateProfile(username: String, bio: String, avatarColor: AvatarColor) async -> Bool {
        guard var profile = currentUser else { return false }
        profile.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.bio = trimmedBio.isEmpty ? nil : trimmedBio
        profile.avatarColor = avatarColor
        do {
            errorMessage = nil
            currentUser = try await repository.updateProfile(profile)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Returns false (with `errorMessage` set) if the account couldn't be
    /// deleted, e.g. Firebase asking for a fresh log-in first.
    @discardableResult
    func deleteAccount() async -> Bool {
        guard let profile = currentUser else { return false }
        do {
            errorMessage = nil
            try await repository.deleteAccount(profile)
            currentUser = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Returns true once the reset email has been requested.
    func sendPasswordReset(email: String) async -> Bool {
        do {
            errorMessage = nil
            try await repository.sendPasswordReset(email: email)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Returns true when the password was changed.
    func changePassword(current: String, new newPassword: String) async -> Bool {
        do {
            errorMessage = nil
            try await repository.changePassword(current: current, new: newPassword)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func logOut() async {
        await repository.logOut()
        currentUser = nil
    }
}
