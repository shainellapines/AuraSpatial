//
//  ForgotPasswordView.swift
//  AuraSpatial
//
//  New screen, opened from "Forgot password?" on Log In. Firebase emails a
//  reset link; the new password is set on Firebase's own secure page, so
//  this app never handles it. The confirmation is the same whether or not
//  the email has an account, so the screen can't be used to find out who
//  has signed up.
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(AuthController.self) private var authController
    @Environment(\.dismiss) private var dismiss

    @State private var email: String
    @State private var isSending = false
    @State private var sentTo: String?
    @FocusState private var isEmailFocused: Bool

    /// Pre-fills the email typed on Log In, if any.
    init(email: String = "") {
        _email = State(initialValue: email)
    }

    private var emailError: String? { CredentialRules.emailError(email) }

    var body: some View {
        ZStack {
            Color.auraBackground.ignoresSafeArea()

            ScrollView {
                if let sentTo {
                    sentState(to: sentTo)
                } else {
                    requestForm
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Reset Password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.auraBackground, for: .navigationBar)
        .onAppear { authController.clearError() }
        .onDisappear { authController.clearError() }
        .animation(.spring(duration: 0.35), value: sentTo)
    }

    // MARK: - Step 1: ask for the email

    private var requestForm: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "key.horizontal.fill")
                .font(.title)
                .foregroundStyle(.auraViolet)
                .frame(width: 64, height: 64)
                .background(Color.auraViolet.opacity(0.15), in: Circle())
                .frame(maxWidth: .infinity)

            Text("Enter the email you signed up with. We'll send you a link to choose a new password.")
                .font(.subheadline)
                .foregroundStyle(.auraTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            AuraLabeledField(
                label: "Email",
                placeholder: "you@example.com",
                text: $email,
                keyboardType: .emailAddress
            )
            .autocorrectionDisabled()
            .focused($isEmailFocused)
            .disabled(isSending)
            .submitLabel(.send)
            .onSubmit(send)
            FieldHint(message: email.isEmpty ? nil : emailError)

            if let errorMessage = authController.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.auraDanger)
            }

            Button(action: send) {
                Group {
                    if isSending {
                        ProgressView().tint(.white)
                    } else {
                        Text("Send Reset Link")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.auraViolet)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isSending || emailError != nil)
            .opacity(emailError == nil ? 1 : 0.5)
            .padding(.top, 4)
        }
        .padding(24)
        .padding(.top, 16)
        .onAppear {
            if email.isEmpty { isEmailFocused = true }
        }
    }

    // MARK: - Step 2: confirmation

    private func sentState(to address: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "envelope.badge.fill")
                .font(.largeTitle)
                .foregroundStyle(.auraTeal)
                .frame(width: 84, height: 84)
                .background(Color.auraTeal.opacity(0.15), in: Circle())
                .auraGlow(.auraTeal, radius: 12)

            Text("Check your inbox")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text("If an account exists for **\(address)**, a reset link is on its way. Open it, choose a new password, then come back and log in.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.auraTextSecondary)

            Label("Not there? Check your Spam folder.", systemImage: "tray.full")
                .font(.footnote)
                .foregroundStyle(.auraTextSecondary)

            Button("Back to Log In") {
                dismiss()
            }
            .buttonStyle(.primaryAura)
            .padding(.top, 8)

            Button("Send again") {
                sentTo = nil
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.auraViolet)
        }
        .padding(24)
        .padding(.top, 32)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private func send() {
        guard emailError == nil, !isSending else { return }
        isEmailFocused = false
        isSending = true
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        Task {
            let succeeded = await authController.sendPasswordReset(email: address)
            isSending = false
            if succeeded {
                sentTo = address
            }
        }
    }
}
