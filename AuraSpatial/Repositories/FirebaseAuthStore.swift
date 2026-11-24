//
//  FirebaseAuthStore.swift
//  AuraSpatial
//
//  AuthRepository backed by Firebase Authentication (email + password) and
//  Cloud Firestore (FR-1.2). Firebase Auth handles the password itself -
//  the app never sees or stores it. The profile (username, bio, avatar
//  color, join date) is one document at `users/{uid}`.
//
//  Only compiled when the Firebase package is linked (see Backend.swift).
//

import Foundation
#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
import FirebaseAuth
import FirebaseFirestore

final class FirebaseAuthStore: AuthRepository {
    private var auth: Auth { Auth.auth() }
    private var users: CollectionReference { Firestore.firestore().collection("users") }

    func currentUser() async -> UserProfile? {
        guard let user = auth.currentUser else { return nil }
        return await loadProfile(for: user)
    }

    func signUp(username: String, email: String, password: String) async throws -> UserProfile {
        let cleanName = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = normalized(email)
        guard !cleanName.isEmpty, !cleanEmail.isEmpty, !password.isEmpty else {
            throw AuthError.missingFields
        }
        if let message = CredentialRules.usernameError(cleanName)
            ?? CredentialRules.emailError(cleanEmail)
            ?? CredentialRules.passwordError(password) {
            throw AuthError.invalidInput(message)
        }

        do {
            let result = try await auth.createUser(withEmail: cleanEmail, password: password)
            let profile = UserProfile(username: cleanName, email: cleanEmail)
            save(profile, uid: result.user.uid)
            return profile
        } catch {
            throw FirebaseErrors.friendly(error)
        }
    }

    func logIn(email: String, password: String) async throws -> UserProfile {
        let cleanEmail = normalized(email)
        guard !cleanEmail.isEmpty, !password.isEmpty else {
            throw AuthError.missingFields
        }
        if let message = CredentialRules.emailError(cleanEmail) {
            throw AuthError.invalidInput(message)
        }

        do {
            let result = try await auth.signIn(withEmail: cleanEmail, password: password)
            return await loadProfile(for: result.user)
        } catch {
            throw FirebaseErrors.friendly(error)
        }
    }

    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        if let message = CredentialRules.usernameError(profile.username) {
            throw AuthError.invalidInput(message)
        }
        guard let uid = auth.currentUser?.uid else {
            throw AuthError.invalidInput("Your session ended. Log in again.")
        }
        save(profile, uid: uid)
        return profile
    }

    /// Deletes the user's layouts, shared soundscapes, profile, and finally
    /// the Firebase account. Firebase only deletes accounts that signed in
    /// recently, so that is checked first - before anything is removed.
    func deleteAccount(_ profile: UserProfile) async throws {
        guard let user = auth.currentUser else { return }
        if let lastSignIn = user.metadata.lastSignInDate,
           Date().timeIntervalSince(lastSignIn) > 4 * 60 {
            throw AuthError.invalidInput("For your security, log out, log in again, then delete your account right away.")
        }

        let database = Firestore.firestore()
        do {
            let layouts = try await users.document(user.uid).collection("layouts").getDocuments()
            for document in layouts.documents {
                try await document.reference.delete()
            }
            let shared = try await database.collection("community")
                .whereField("creatorUID", isEqualTo: user.uid)
                .getDocuments()
            for document in shared.documents {
                try await document.reference.delete()
            }
            try await users.document(user.uid).delete()
            try await user.delete()
        } catch {
            throw FirebaseErrors.friendly(error)
        }
    }

    func logOut() async {
        try? auth.signOut()
    }

    /// Firebase emails a link to a Firebase-hosted page where the new
    /// password is typed. An unknown email is treated as success, so the
    /// screen never reveals which emails have accounts.
    func sendPasswordReset(email: String) async throws {
        let cleanEmail = normalized(email)
        if let message = CredentialRules.emailError(cleanEmail) {
            throw AuthError.invalidInput(message)
        }
        do {
            try await auth.sendPasswordReset(withEmail: cleanEmail)
        } catch {
            let nsError = error as NSError
            if nsError.domain == "FIRAuthErrorDomain" && nsError.code == 17011 {
                return
            }
            throw FirebaseErrors.friendly(error)
        }
    }

    /// Firebase only changes a password right after the user proves who
    /// they are, so the current password is checked first
    /// (reauthentication), then the new one is set.
    func changePassword(current: String, new newPassword: String) async throws {
        guard let user = auth.currentUser, let email = user.email else {
            throw AuthError.invalidInput("Your session ended. Log in again.")
        }
        if let message = CredentialRules.passwordError(newPassword) {
            throw AuthError.invalidInput(message)
        }
        do {
            let credential = EmailAuthProvider.credential(withEmail: email, password: current)
            _ = try await user.reauthenticate(with: credential)
            try await user.updatePassword(to: newPassword)
        } catch {
            let nsError = error as NSError
            if nsError.domain == "FIRAuthErrorDomain" && [17004, 17009].contains(nsError.code) {
                throw AuthError.invalidInput("Your current password is incorrect.")
            }
            throw FirebaseErrors.friendly(error)
        }
    }

    // MARK: - Private helpers

    private func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Writes the profile to `users/{uid}`. The write lands in Firestore's
    /// local cache at once and syncs in the background (works offline).
    private func save(_ profile: UserProfile, uid: String) {
        do {
            let data = try Firestore.Encoder().encode(profile)
            users.document(uid).setData(data) { error in
                if let error {
                    print("⚠️ Profile sync failed: \(error.localizedDescription)")
                }
            }
        } catch {
            print("⚠️ Profile encode failed: \(error.localizedDescription)")
        }
    }

    /// Reads `users/{uid}`. If the account has no profile document yet
    /// (e.g. created in the Firebase console), one is made from the email.
    /// If the read fails (offline), a temporary profile is shown and
    /// nothing is overwritten.
    private func loadProfile(for user: User) async -> UserProfile {
        let fallback = UserProfile(
            username: user.email?.components(separatedBy: "@").first ?? "listener",
            email: user.email ?? ""
        )
        do {
            let snapshot = try await users.document(user.uid).getDocument()
            if snapshot.exists, let profile = try? snapshot.data(as: UserProfile.self) {
                return profile
            }
            save(fallback, uid: user.uid)
            return fallback
        } catch {
            return fallback
        }
    }
}

/// Turns Firebase error codes into the app's own friendly messages.
/// Numeric codes are used because they are the same in every Firebase
/// SDK version (the Swift enum names have changed between versions).
enum FirebaseErrors {
    private static let authDomain = "FIRAuthErrorDomain"
    private static let firestoreDomain = "FIRFirestoreErrorDomain"

    static func friendly(_ error: Error) -> Error {
        let nsError = error as NSError
        if nsError.domain == authDomain {
            switch nsError.code {
            case 17007: return AuthError.emailInUse
            case 17008: return AuthError.invalidInput("Enter a valid email, like you@example.com.")
            case 17004, 17009: return AuthError.invalidInput("The email or password is incorrect.")
            case 17011: return AuthError.accountNotFound
            case 17026: return AuthError.invalidInput("Choose a stronger password (at least 6 characters).")
            case 17010: return AuthError.invalidInput("Too many attempts. Wait a moment and try again.")
            case 17020: return AuthError.invalidInput("You're offline. Check your connection and try again.")
            case 17014: return AuthError.invalidInput("For your security, log out, log in again, then try once more.")
            default: return error
            }
        }
        if nsError.domain == firestoreDomain {
            switch nsError.code {
            case 7: return AuthError.invalidInput("Firebase blocked this request. Check the Firestore security rules (see FIREBASE_SETUP.md).")
            case 14: return AuthError.invalidInput("You're offline. Check your connection and try again.")
            default: return error
            }
        }
        return error
    }
}
#endif
