//
//  ProfileView.swift
//  AuraSpatial
//
//  Screen 9, now its own tab: who you are, how you listen, and every
//  setting. Sections, top to bottom:
//    1. Identity - avatar, username, email, bio, member since (editable)
//    2. Listening stats - real numbers recorded by the Canvas
//    3. Your sound mix - which categories you place most
//    4. Settings - audio, canvas, sessions (ProfileSettingsSections.swift)
//    5. Data & privacy, About, and account actions
//

import SwiftUI

struct ProfileView: View {
    @Environment(AuthController.self) private var authController
    @Environment(CanvasController.self) private var canvasController
    @Environment(SavedLayoutsController.self) private var savedLayoutsController
    @Environment(SettingsController.self) private var settingsController

    @State private var showingEditProfile = false
    @State private var showingChangePassword = false
    @State private var confirmation: ProfileConfirmation?
    @State private var toastMessage: String?
    @State private var accountError: String?

    var body: some View {
        @Bindable var settingsController = settingsController

        NavigationStack {
            ZStack {
                Color.auraBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        if let user = authController.currentUser {
                            ProfileHeaderCard(user: user) {
                                showingEditProfile = true
                            }
                        }

                        ListeningStatsGrid(
                            stats: canvasController.stats,
                            layoutCount: savedLayoutsController.savedLayouts.count
                        )

                        CategoryMixCard(stats: canvasController.stats)

                        AudioSettingsSection(settings: $settingsController.settings)
                        CanvasSettingsSection(settings: $settingsController.settings)
                        SessionSettingsSection(settings: $settingsController.settings)

                        AccountSection(
                            email: authController.currentUser?.email ?? "",
                            onChangePassword: { showingChangePassword = true }
                        )

                        DataSection(
                            layoutCount: savedLayoutsController.savedLayouts.count,
                            onResetStats: { confirmation = .resetStats },
                            onDeleteLayouts: { confirmation = .deleteLayouts },
                            onResetSettings: { confirmation = .resetSettings }
                        )

                        AboutSection()

                        accountActions
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Profile")
            .toolbarBackground(Color.auraBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { showingEditProfile = true }
                        .foregroundStyle(.auraViolet)
                }
            }
            .auraToast($toastMessage)
            .alert("Couldn't delete account", isPresented: accountErrorBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(accountError ?? "")
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingChangePassword) {
                ChangePasswordView {
                    toastMessage = "Password updated"
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .confirmationDialog(
                confirmation?.title ?? "",
                isPresented: confirmationBinding,
                titleVisibility: .visible,
                presenting: confirmation
            ) { item in
                Button(item.actionTitle, role: .destructive) {
                    perform(item)
                }
                Button("Cancel", role: .cancel) { }
            } message: { item in
                Text(item.message)
            }
        }
    }

    private var accountActions: some View {
        VStack(spacing: 12) {
            Button("Log Out") {
                confirmation = .logOut
            }
            .buttonStyle(.secondaryAura)

            Button("Delete Account") {
                confirmation = .deleteAccount
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.auraDanger)
            .padding(.top, 4)
        }
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { confirmation != nil },
            set: { isPresented in
                if !isPresented { confirmation = nil }
            }
        )
    }

    private func perform(_ item: ProfileConfirmation) {
        switch item {
        case .resetStats:
            canvasController.resetStats()
            toastMessage = "Listening stats reset"
        case .deleteLayouts:
            Task {
                await savedLayoutsController.deleteAll()
                toastMessage = "Saved layouts deleted"
            }
        case .resetSettings:
            settingsController.resetToDefaults()
            toastMessage = "Settings restored"
        case .logOut:
            canvasController.clearAll()
            Task { await authController.logOut() }
        case .deleteAccount:
            Task {
                if await authController.deleteAccount() {
                    canvasController.clearAll()
                } else {
                    accountError = authController.errorMessage
                }
            }
        }
    }

    private var accountErrorBinding: Binding<Bool> {
        Binding(
            get: { accountError != nil },
            set: { isPresented in
                if !isPresented { accountError = nil }
            }
        )
    }
}

/// Every action on this screen that asks "are you sure?" first.
enum ProfileConfirmation: Identifiable {
    case resetStats
    case deleteLayouts
    case resetSettings
    case logOut
    case deleteAccount

    var id: Self { self }

    var title: String {
        switch self {
        case .resetStats: "Reset listening stats?"
        case .deleteLayouts: "Delete all saved layouts?"
        case .resetSettings: "Restore default settings?"
        case .logOut: "Log out of AuraSpatial?"
        case .deleteAccount: "Delete your account?"
        }
    }

    var actionTitle: String {
        switch self {
        case .resetStats: "Reset Stats"
        case .deleteLayouts: "Delete All Layouts"
        case .resetSettings: "Restore Defaults"
        case .logOut: "Log Out"
        case .deleteAccount: "Delete Account"
        }
    }

    var message: String {
        switch self {
        case .resetStats: "Listening time, sounds placed, and sessions go back to zero."
        case .deleteLayouts: Backend.isCloud
            ? "Every saved layout in your account is removed from Firebase. This can't be undone."
            : "Every saved layout on this device is removed. This can't be undone."
        case .resetSettings: "Volume, spatial mode, canvas, and timer settings return to their defaults."
        case .logOut: Backend.isCloud
            ? "Your account and layouts stay safe in Firebase. Log in again on any device."
            : "Your account and layouts stay on this device. Log in again any time."
        case .deleteAccount: Backend.isCloud
            ? "Your account, saved layouts, and shared soundscapes are deleted from Firebase. This can't be undone."
            : "Your account is removed from this device and you're signed out. This can't be undone."
        }
    }
}

// MARK: - Identity

private struct ProfileHeaderCard: View {
    let user: UserProfile
    let onEdit: () -> Void

    private var avatarColor: Color {
        (user.avatarColor ?? .violet).color
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(avatarColor.opacity(0.18))
                    .frame(width: 104, height: 104)
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .frame(width: 128, height: 128)
                Circle()
                    .fill(avatarColor)
                    .frame(width: 80, height: 80)
                    .auraGlow(avatarColor, radius: 20)
                Text(user.initials)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(height: 130)

            VStack(spacing: 4) {
                Text(user.username)
                    .auraDisplayFont(24)
                    .foregroundStyle(.white)
                Text(user.email)
                    .font(.subheadline)
                    .foregroundStyle(.auraTextSecondary)
            }

            if let bio = user.bio, !bio.isEmpty {
                Text(bio)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.85))
                    .padding(.horizontal, 12)
            } else {
                Button("Add a short bio", action: onEdit)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.auraViolet)
            }

            HStack(spacing: 6) {
                Image(systemName: "calendar")
                Text("Member since \(user.joinedAt.formatted(.dateTime.month(.wide).year()))")
            }
            .font(.caption)
            .foregroundStyle(.auraTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.auraSurface, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Stats

private struct ListeningStatsGrid: View {
    let stats: UsageStats
    let layoutCount: Int

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Listening")
            LazyVGrid(columns: columns, spacing: 12) {
                StatTile(icon: "headphones", tint: .auraViolet, value: AuraFormat.listeningTime(stats.listeningSeconds), label: "Time listening")
                StatTile(icon: "square.grid.2x2.fill", tint: .auraTeal, value: "\(layoutCount)", label: layoutCount == 1 ? "Saved layout" : "Saved layouts")
                StatTile(icon: "waveform", tint: .auraAmber, value: "\(stats.soundsPlaced)", label: stats.soundsPlaced == 1 ? "Sound placed" : "Sounds placed")
                StatTile(
                    icon: "checkmark.seal.fill",
                    tint: .auraRose,
                    value: "\(stats.sessionsCompleted)",
                    label: "\(stats.focusSessionsCompleted) focus · \(stats.sleepSessionsCompleted) sleep"
                )
            }
        }
    }
}

private struct StatTile: View {
    let icon: String
    let tint: Color
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 9))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.auraTextSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.auraSurface, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// A single stacked bar of category placements, with a legend.
private struct CategoryMixCard: View {
    let stats: UsageStats

    private var total: Int {
        SoundCategory.allCases.reduce(0) { $0 + stats.placements(for: $1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeading(title: "Your sound mix")
                Spacer()
                if let favorite = stats.favoriteCategory {
                    PillBadge(text: "Mostly \(favorite.rawValue)", color: favorite.accentColor, filled: false)
                }
            }

            if total == 0 {
                Text("Place a few sounds on the Canvas and your mix shows up here.")
                    .font(.footnote)
                    .foregroundStyle(.auraTextSecondary)
            } else {
                GeometryReader { proxy in
                    HStack(spacing: 3) {
                        ForEach(SoundCategory.allCases) { category in
                            let count = stats.placements(for: category)
                            if count > 0 {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(category.accentColor)
                                    .frame(width: max(6, (proxy.size.width - 6) * CGFloat(count) / CGFloat(total)))
                            }
                        }
                    }
                }
                .frame(height: 12)

                HStack(spacing: 16) {
                    ForEach(SoundCategory.allCases) { category in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(category.accentColor)
                                .frame(width: 8, height: 8)
                            Text("\(category.rawValue) \(AuraFormat.percent(Double(stats.placements(for: category)) / Double(total)))")
                                .font(.caption)
                                .foregroundStyle(.auraTextSecondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.auraSurface, in: RoundedRectangle(cornerRadius: 18))
    }
}

/// Small uppercase heading used above each Profile section.
struct SectionHeading: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .tracking(0.8)
            .foregroundStyle(.auraTextSecondary)
    }
}
