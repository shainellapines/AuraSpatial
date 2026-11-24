//
//  LogInView.swift
//  AuraSpatial
//
//  Screen 3 (SRS Section 5): returning-user entry into the simulated
//  session (FR-1.1). Rebuilt with AuraLabeledField to match the
//  prototype's dark rounded fields with uppercase captions, replacing the
//  plain system Form the first draft used.
//
//  Bug fixes: "Sign Up" under the button was plain text - it's now a real
//  link. Log In also checks the email format and the account that Sign Up
//  created, instead of accepting anything.
//
//  "Forgot password?" opens ForgotPasswordView (a Firebase reset email).
//

import SwiftUI

struct LogInView: View {
    @Environment(AuthController.self) private var authController
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    private var emailError: String? { CredentialRules.emailError(email) }

    private var isFormValid: Bool {
        emailError == nil && !password.isEmpty
    }

    var body: some View {
        ZStack {
            Color.auraBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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
                        placeholder: "Your password",
                        text: $password,
                        isSecure: true
                    )
                    .focused($focusedField, equals: .password)
                    .disabled(isLoading)
                    .submitLabel(.go)
                    .onSubmit {
                        if isFormValid {
                            performLogin()
                        }
                    }

                    HStack {
                        Spacer()
                        NavigationLink {
                            ForgotPasswordView(email: email)
                        } label: {
                            Text("Forgot password?")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.auraViolet)
                        }
                        .disabled(isLoading)
                    }
                    .padding(.top, -8)

                    if let errorMessage = authController.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.auraDanger)
                            .font(.footnote)
                    }

                    Button {
                        performLogin()
                    } label: {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Log In")
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

                    HStack(spacing: 4) {
                        Spacer()
                        Text("Don't have an account?")
                            .foregroundStyle(.auraTextSecondary)
                        NavigationLink {
                            SignUpView()
                        } label: {
                            Text("Sign Up")
                                .fontWeight(.semibold)
                                .foregroundStyle(.auraViolet)
                        }
                        Spacer()
                    }
                    .font(.subheadline)
                }
                .padding(24)
                .padding(.top, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Log In")
        .toolbarBackground(Color.auraBackground, for: .navigationBar)
        .onDisappear { authController.clearError() }
        .onAppear {
            // Focus email field on appear for better UX
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .email
            }
        }
    }
    
    private func performLogin() {
        focusedField = nil // Dismiss keyboard
        isLoading = true
        
        Task { @MainActor in
            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
            
            await authController.logIn(email: trimmedEmail, password: trimmedPassword)
            isLoading = false
        }
    }
}
