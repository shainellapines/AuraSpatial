//
//  CredentialRules.swift
//  AuraSpatial
//
//  The sign-up / log-in validation rules, in one place, so the Views (for
//  inline hints) and LocalAuthStore (as a final check) always agree.
//  Each function returns nil when the value is valid, or a message.
//

import Foundation

enum CredentialRules {
    static let minimumPasswordLength = 6
    static let usernameLengthRange = 2...24

    static func usernameError(_ username: String) -> String? {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard usernameLengthRange.contains(trimmed.count) else {
            return "Username must be \(usernameLengthRange.lowerBound)–\(usernameLengthRange.upperBound) characters."
        }
        let allowed = trimmed.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
        guard allowed else {
            return "Use letters, numbers, dots, or underscores only."
        }
        return nil
    }

    static func emailError(_ email: String) -> String? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = "Enter a valid email, like you@example.com."
        guard !trimmed.contains(" ") else { return message }
        let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return message }
        let domain = parts[1]
        guard domain.contains("."), !domain.hasPrefix("."), !domain.hasSuffix(".") else { return message }
        return nil
    }

    static func passwordError(_ password: String) -> String? {
        guard password.count >= minimumPasswordLength else {
            return "Password needs at least \(minimumPasswordLength) characters."
        }
        return nil
    }
}
