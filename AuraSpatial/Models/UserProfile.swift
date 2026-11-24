//
//  UserProfile.swift
//  AuraSpatial
//
//  The signed-in (simulated, for the midterm) user (FR-1.1). Mirrors the
//  shape the final build's Firebase Auth / Firestore user record will take
//  (see the SRS, Section 4.2).
//
//  `bio` and `avatarColor` are Optional so profiles saved by the previous
//  version of the app still decode.
//

import Foundation

struct UserProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var username: String
    var email: String
    var joinedAt: Date
    var bio: String?
    var avatarColor: AvatarColor?

    init(
        id: UUID = UUID(),
        username: String,
        email: String,
        joinedAt: Date = Date(),
        bio: String? = nil,
        avatarColor: AvatarColor? = nil
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.joinedAt = joinedAt
        self.bio = bio
        self.avatarColor = avatarColor
    }

    /// Up to two letters for the avatar circle.
    var initials: String {
        let letters = username
            .split(whereSeparator: { $0 == " " || $0 == "_" || $0 == "." })
            .prefix(2)
            .compactMap { $0.first }
        let result = String(letters).uppercased()
        return result.isEmpty ? "?" : result
    }
}
