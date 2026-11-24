//
//  EditProfileView.swift
//  AuraSpatial
//
//  New screen: edit your username, bio, and avatar color. The email is
//  shown but read-only (it's the account's sign-in key). Validation uses
//  the same CredentialRules as Sign Up.
//

import SwiftUI

struct EditProfileView: View {
    @Environment(AuthController.self) private var authController
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var bio = ""
    @State private var avatarColor: AvatarColor = .violet
    @State private var isSaving = false
    @State private var didLoad = false

    private let bioLimit = 120

    private var usernameError: String? {
        CredentialRules.usernameError(username)
    }

    private var initials: String {
        UserProfile(username: username, email: "").initials
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.auraBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        avatarPreview
                        colorPicker

                        VStack(alignment: .leading, spacing: 6) {
                            AuraLabeledField(label: "Username", placeholder: "Your name", text: $username)
                                .autocorrectionDisabled()
                            if let usernameError, !username.isEmpty {
                                Text(usernameError)
                                    .font(.caption)
                                    .foregroundStyle(.auraDanger)
                            }
                        }

                        bioField

                        VStack(alignment: .leading, spacing: 8) {
                            Text("EMAIL")
                                .font(.caption2.weight(.semibold))
                                .tracking(0.8)
                                .foregroundStyle(.auraTextSecondary)
                            HStack {
                                Text(authController.currentUser?.email ?? "")
                                    .foregroundStyle(.auraTextSecondary)
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.auraTextSecondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.auraSurface.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
                        }

                        if let errorMessage = authController.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.auraDanger)
                        }
                    }
                    .padding(24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.auraBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(usernameError != nil || isSaving)
                }
            }
            .onAppear(perform: loadCurrentValues)
            .onDisappear { authController.clearError() }
        }
    }

    private var avatarPreview: some View {
        HStack {
            Spacer()
            ZStack {
                Circle()
                    .fill(avatarColor.color)
                    .frame(width: 84, height: 84)
                    .auraGlow(avatarColor.color, radius: 18)
                Text(initials)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .animation(.spring(duration: 0.3), value: avatarColor)
            Spacer()
        }
        .padding(.top, 8)
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AVATAR COLOR")
                .font(.caption2.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(.auraTextSecondary)
            HStack(spacing: 14) {
                ForEach(AvatarColor.allCases) { option in
                    Button {
                        avatarColor = option
                    } label: {
                        Circle()
                            .fill(option.color)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: option == avatarColor ? 3 : 0)
                                    .padding(-4)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.rawValue.capitalized)
                    .accessibilityAddTraits(option == avatarColor ? .isSelected : [])
                }
            }
        }
    }

    private var bioField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BIO")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.auraTextSecondary)
                Spacer()
                Text("\(bio.count)/\(bioLimit)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(bio.count > bioLimit ? Color.auraDanger : Color.auraTextSecondary)
            }
            TextField("What do you listen to, and when?", text: $bio, axis: .vertical)
                .lineLimit(2...4)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.auraSurface, in: RoundedRectangle(cornerRadius: 14))
                .onChange(of: bio) { _, newValue in
                    if newValue.count > bioLimit {
                        bio = String(newValue.prefix(bioLimit))
                    }
                }
        }
    }

    private func loadCurrentValues() {
        guard !didLoad, let user = authController.currentUser else { return }
        username = user.username
        bio = user.bio ?? ""
        avatarColor = user.avatarColor ?? .violet
        didLoad = true
    }

    private func save() {
        isSaving = true
        Task {
            let succeeded = await authController.updateProfile(username: username, bio: bio, avatarColor: avatarColor)
            isSaving = false
            if succeeded { dismiss() }
        }
    }
}
