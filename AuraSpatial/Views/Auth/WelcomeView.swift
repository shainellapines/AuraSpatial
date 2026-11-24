//
//  WelcomeView.swift
//  AuraSpatial
//
//  Screen 1 (SRS Section 5): entry point, routes to Sign Up or Log In.
//  Rebuilt to match the real prototype: a glowing violet headphones icon,
//  a bold rounded display title, and a small live preview of the orbit
//  motif used throughout the app.
//

import SwiftUI

struct WelcomeView: View {
    var body: some View {
        ZStack {
            Color.auraBackground.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "headphones")
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
                    .frame(width: 84, height: 84)
                    .background(Color.auraViolet, in: Circle())
                    .auraGlow(.auraViolet, radius: 28)

                VStack(spacing: 10) {
                    Text("AuraSpatial")
                        .auraDisplayFont(38, weight: .heavy)
                        .foregroundStyle(.white)
                    Text("Build 3D soundscapes.\nPlace audio in your world.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.auraTextSecondary)
                }

                OrbitGlyph(size: 140)
                    .padding(.top, 8)

                Spacer()

                VStack(spacing: 14) {
                    NavigationLink {
                        LogInView()
                    } label: {
                        Text("Log In")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.auraViolet, in: Capsule())
                            .foregroundStyle(.white)
                    }

                    NavigationLink {
                        SignUpView()
                    } label: {
                        Text("Sign Up")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.06), in: Capsule())
                            .foregroundStyle(.white)
                            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    NavigationStack {
        WelcomeView()
    }
    .environment(AuthController())
}
