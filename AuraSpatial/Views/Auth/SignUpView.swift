//
//  SignUpView.swift
//  AuraSpatial
//
//  Screen 2 (SRS Section 5): account creation, gated by the simulated
//  local session (FR-1.1). Rebuilt with AuraLabeledField to match the
//  prototype's dark field styling.
//
//  Bug fix: the form used to accept anything ("tyty" as an email). It now
//  checks the username, email format, and password length (CredentialRules)
//  and shows a hint under each field as you type.
//

import SwiftUI

struct SignUpView: View {
    @Environment(AuthController.self) private var authController
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case username, email, password
    }
    
    private var usernameError: String? { CredentialRules.usernameError(username) }
    private var emailError: String? { CredentialRules.emailError(email) }
    private var passwordError: String? { CredentialRules.passwordError(password) }

    private var isFormValid: Bool {
        usernameError == nil && emailError == nil && passwordError == nil
    }

    var body: some View {
        ZStack {
            Color.auraBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AuraLabeledField(
                        label: "Username",
                        placeholder: "Your name",
                        text: $username
                    )
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .username)
                    .disabled(isLoading)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .email
                    }
                    FieldHint(message: username.isEmpty ? nil : usernameError)
                    
                    AuraLabeledField(
                        label: "Email",
                        placeholder: "you@example.com",
                        text: $email,
                        keyboardType: .emailAddress
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .disabled(isLoading)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .password
                    }
                    FieldHint(message: email.isEmpty ? nil : emailError)
                    
                    AuraLabeledField(
                        label: "Password",
                        placeholder: "Choose a password",
                        text: $password,
                        isSecure: true
                    )
                    .focused($focusedField, equals: .password)
                    .disabled(isLoading)
                    .submitLabel(.go)
                    .onSubmit {
                        if isFormValid {
                            performSignUp()
                        }
                    }
                    FieldHint(
                        message: password.isEmpty ? nil : passwordError,
                        fallback: "At least \(CredentialRules.minimumPasswordLength) characters."
                    )

                    if let errorMessage = authController.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.auraDanger)
                            .font(.footnote)
                    }

                    Button {
                        performSignUp()
                    } label: {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Sign Up")
                                    .font(.system(.body, design: .rounded).weight(.semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.auraViolet)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isLoading || !isFormValid)
                    .opacity(isFormValid ? 1.0 : 0.5)
                    .allowsHitTesting(!isLoading && isFormValid)
                    .padding(.top, 8)
                }
                .padding(24)
                .padding(.top, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Sign Up")
        .toolbarBackground(Color.auraBackground, for: .navigationBar)
        .onDisappear { authController.clearError() }
        .onAppear {
            // Focus username field on appear for better UX
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .username
            }
        }
    }
    
    private func performSignUp() {
        focusedField = nil // Dismiss keyboard
        isLoading = true
        
        Task { @MainActor in
            let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
            
            await authController.signUp(username: trimmedUsername, email: trimmedEmail, password: trimmedPassword)
            isLoading = false
        }
    }
}

/// A small hint under a form field: red when there's a problem, gray for
/// a neutral tip, hidden otherwise.
struct FieldHint: View {
    let message: String?
    var fallback: String?

    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.auraDanger)
                .padding(.top, -12)
                .transition(.opacity)
        } else if let fallback {
            Text(fallback)
                .font(.caption)
                .foregroundStyle(.auraTextSecondary)
                .padding(.top, -12)
        }
    }
}
