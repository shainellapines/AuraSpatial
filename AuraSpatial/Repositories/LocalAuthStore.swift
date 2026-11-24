//
//  LocalAuthStore.swift
//  AuraSpatial
//
//  Midterm implementation of AuthRepository - no server calls. Accounts
//  are kept in UserDefaults with a SHA-256 hash of the password (never the
//  password itself), and the current session is a mirrored UserProfile
//  (FR-1.1, FR-1.3).
//
//  Bug fix: Log In used to accept ANY email/password and create a brand
//  new profile (losing the username and join date). It now checks the
//  account that Sign Up created.
//

import Foundation
import CryptoKit

final class LocalAuthStore: AuthRepository {
    private struct StoredAccount: Codable {
        var profile: UserProfile
        var passwordHash: String
    }

    private let defaults: UserDefaults
    private let sessionKey = "auraspatial.session.user"
    private let accountsKey = "auraspatial.accounts"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func currentUser() async -> UserProfile? {
        guard let data = defaults.data(forKey: sessionKey) else { return nil }
        return try? JSONDecoder.auraSpatial.decode(UserProfile.self, from: data)
    }

    func signUp(username: String, email: String, password: String) async throws -> UserProfile {
        let cleanEmail = normalized(email)
        guard !username.isEmpty, !cleanEmail.isEmpty, !password.isEmpty else {
            throw AuthError.missingFields
        }
        if let message = CredentialRules.usernameError(username)
            ?? CredentialRules.emailError(cleanEmail)
            ?? CredentialRules.passwordError(password) {
            throw AuthError.invalidInput(message)
        }

        var accounts = loadAccounts()
        guard accounts[cleanEmail] == nil else { throw AuthError.emailInUse }

        let profile = UserProfile(username: username, email: cleanEmail)
        accounts[cleanEmail] = StoredAccount(profile: profile, passwordHash: hash(password, email: cleanEmail))
        try saveAccounts(accounts)
        try persistSession(profile)
        return profile
    }

    func logIn(email: String, password: String) async throws -> UserProfile {
        let cleanEmail = normalized(email)
        guard !cleanEmail.isEmpty, !password.isEmpty else {
            throw AuthError.missingFields
        }
        if let message = CredentialRules.emailError(cleanEmail) {
            throw AuthError.invalidInput(message)
        }
        guard let account = loadAccounts()[cleanEmail] else {
            throw AuthError.accountNotFound
        }
        guard account.passwordHash == hash(password, email: cleanEmail) else {
            throw AuthError.invalidCredentials
        }
        try persistSession(account.profile)
        return account.profile
    }

    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        if let message = CredentialRules.usernameError(profile.username) {
            throw AuthError.invalidInput(message)
        }
        var accounts = loadAccounts()
        let key = normalized(profile.email)
        if var account = accounts[key] {
            account.profile = profile
            accounts[key] = account
            try saveAccounts(accounts)
        }
        try persistSession(profile)
        return profile
    }

    func deleteAccount(_ profile: UserProfile) async throws {
        var accounts = loadAccounts()
        accounts.removeValue(forKey: normalized(profile.email))
        try? saveAccounts(accounts)
        defaults.removeObject(forKey: sessionKey)
    }

    /// There's no email server on-device, so resetting by email needs
    /// Firebase. (Change Password still works locally.)
    func sendPasswordReset(email: String) async throws {
        throw AuthError.invalidInput("Password reset emails need Firebase. Connect it first (see FIREBASE_SETUP.md).")
    }

    /// Verifies the current password's hash, then stores the new one.
    func changePassword(current: String, new newPassword: String) async throws {
        guard let profile = await currentUser() else {
            throw AuthError.invalidInput("Your session ended. Log in again.")
        }
        if let message = CredentialRules.passwordError(newPassword) {
            throw AuthError.invalidInput(message)
        }
        let key = normalized(profile.email)
        var accounts = loadAccounts()
        guard var account = accounts[key] else { throw AuthError.accountNotFound }
        guard account.passwordHash == hash(current, email: key) else {
            throw AuthError.invalidInput("Your current password is incorrect.")
        }
        account.passwordHash = hash(newPassword, email: key)
        accounts[key] = account
        try saveAccounts(accounts)
    }

    func logOut() async {
        defaults.removeObject(forKey: sessionKey)
    }

    // MARK: - Private helpers

    private func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func hash(_ password: String, email: String) -> String {
        let digest = SHA256.hash(data: Data((email + ":" + password).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func loadAccounts() -> [String: StoredAccount] {
        guard let data = defaults.data(forKey: accountsKey),
              let accounts = try? JSONDecoder.auraSpatial.decode([String: StoredAccount].self, from: data) else {
            return [:]
        }
        return accounts
    }

    private func saveAccounts(_ accounts: [String: StoredAccount]) throws {
        let data = try JSONEncoder.auraSpatial.encode(accounts)
        defaults.set(data, forKey: accountsKey)
    }

    private func persistSession(_ profile: UserProfile) throws {
        let data = try JSONEncoder.auraSpatial.encode(profile)
        defaults.set(data, forKey: sessionKey)
    }
}
