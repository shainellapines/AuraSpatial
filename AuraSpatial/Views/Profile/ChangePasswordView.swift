//
//  ChangePasswordView.swift
//  AuraSpatial
//
//  New screen (Profile > Account > Change Password). Asks for the current
//  password first: Firebase re-checks it (reauthentication) before it
//  allows a new one, so someone holding your unlocked phone can't change
//  it. The new password follows the same rules as Sign Up.
//

import SwiftUI

struct ChangePasswordView: View {
    @Environment(AuthController.self) private var authController
    @Environment(\.dismiss) private var dismiss

    /// Called after a successful change, so Profile can show a toast.
    let onChanged: () -> Void

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case current, new, confirm
    }

    private var newPasswordError: String? {
        guard !newPassword.isEmpty else { return nil }
        if let message = CredentialRules.passwordError(newPassword) { return message }
        if newPassword == currentPassword { return "Choose a password different from your current one." }
        return nil
    }

    private var confirmError: String? {
        guard !confirmPassword.isEmpty, confirmPassword != newPassword else { return nil }
        return "Passwords don't match."
    }

    private var isFormValid: Bool {
        !currentPassword.isEmpty
            && CredentialRules.passwordError(newPassword) == nil
            && newPassword != currentPassword
            && confirmPassword == newPassword
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.auraBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("For your security, enter your current password first.")
                            .font(.subheadline)
                            .foregroundStyle(.auraTextSecondary)

                        AuraLabeledField(label: "Current password", placeholder: "Your current password", text: $currentPassword, isSecure: true)
                            .focused($focusedField, equals: .current)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .new }

                        AuraLabeledField(label: "New password", placeholder: "At least \(CredentialRules.minimumPasswordLength) characters", text: $newPassword, isSecure: true)
                            .focused($focusedField, equals: .new)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .confirm }
                        FieldHint(
                            message: newPasswordError,
                            fallback: "At least \(CredentialRules.minimumPasswordLength) characters."
                        )

                        AuraLabeledField(label: "Confirm new password", placeholder: "Type it again", text: $confirmPassword, isSecure: true)
                            .focused($focusedField, equals: .confirm)
                            .submitLabel(.done)
                            .onSubmit(save)
                        FieldHint(message: confirmError)

                        if let errorMessage = authController.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.auraDanger)
                        }

                        Button(action: save) {
                            Group {
                                if isSaving {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Update Password")
                                        .font(.system(.body, design: .rounded).weight(.semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.auraViolet)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(!isFormValid || isSaving)
                        .opacity(isFormValid ? 1 : 0.5)
                        .padding(.top, 4)
                    }
                    .padding(24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.auraBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                authController.clearError()
                focusedField = .current
            }
            .onDisappear { authController.clearError() }
        }
    }

    private func save() {
        guard isFormValid, !isSaving else { return }
        focusedField = nil
        isSaving = true
        Task {
            let succeeded = await authController.changePassword(current: currentPassword, new: newPassword)
            isSaving = false
            if succeeded {
                onChanged()
                dismiss()
            }
        }
    }
}
