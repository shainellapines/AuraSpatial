//
//  ProfileSettingsSections.swift
//  AuraSpatial
//
//  The Settings cards on the Profile screen. Each section binds straight
//  to AppSettings; RootTabView saves every change and applies it to the
//  audio engine immediately, so you hear a volume or 3D change as you
//  make it.
//

import SwiftUI
import UIKit

// MARK: - Audio

struct AudioSettingsSection: View {
    @Binding var settings: AppSettings

    var body: some View {
        SettingsCard(title: "Audio") {
            VStack(alignment: .leading, spacing: 10) {
                SettingsRowLabel(icon: "speaker.wave.3.fill", tint: .auraViolet, title: "Master volume") {
                    Text(AuraFormat.percent(settings.masterVolume))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.auraViolet)
                }
                Slider(value: $settings.masterVolume, in: 0...1)
                    .tint(.auraViolet)
            }

            SettingsDivider()

            VStack(alignment: .leading, spacing: 10) {
                SettingsRowLabel(icon: "visionpro", tint: .auraTeal, title: "Spatial rendering") {
                    EmptyView()
                }
                Picker("Spatial rendering", selection: $settings.spatialMode) {
                    ForEach(SpatialRenderMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Text(settings.spatialMode.detail)
                    .font(.caption)
                    .foregroundStyle(.auraTextSecondary)
            }

            SettingsDivider()

            SettingsToggleRow(
                icon: "hand.tap.fill",
                tint: .auraAmber,
                title: "Haptics",
                subtitle: "Taps when you select a sound or a session ends",
                isOn: $settings.hapticsEnabled
            )
        }
    }
}

// MARK: - Canvas

struct CanvasSettingsSection: View {
    @Binding var settings: AppSettings

    var body: some View {
        SettingsCard(title: "Canvas") {
            SettingsToggleRow(
                icon: "dot.radiowaves.left.and.right",
                tint: .auraViolet,
                title: "Sound waves",
                subtitle: "Beams and ripples that follow each sound's loudness",
                isOn: $settings.showSoundWaves
            )

            SettingsDivider()

            SettingsToggleRow(
                icon: "scope",
                tint: .auraTeal,
                title: "Distance guides",
                subtitle: "Near / Mid / Far rings and Front / Back labels",
                isOn: $settings.showDistanceGuides
            )

            SettingsDivider()

            VStack(alignment: .leading, spacing: 10) {
                SettingsRowLabel(icon: "rotate.3d", tint: .auraAmber, title: "Orbit speed") {
                    EmptyView()
                }
                Picker("Orbit speed", selection: $settings.orbitSpeed) {
                    ForEach(OrbitSpeed.allCases) { speed in
                        Text(speed.label).tag(speed)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

// MARK: - Sessions

struct SessionSettingsSection: View {
    @Binding var settings: AppSettings

    var body: some View {
        SettingsCard(title: "Sessions") {
            NotificationSettingsRow()

            SettingsDivider()

            SettingsRowLabel(icon: "timer", tint: .auraTeal, title: "Default timer") {
                Picker("Default timer", selection: $settings.defaultTimerMinutes) {
                    ForEach(AppSettings.timerChoices, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                .pickerStyle(.menu)
                .tint(.auraTeal)
            }

            SettingsDivider()

            VStack(alignment: .leading, spacing: 10) {
                SettingsRowLabel(icon: "speaker.zzz.fill", tint: .auraViolet, title: "Fade-out length") {
                    EmptyView()
                }
                Picker("Fade-out length", selection: $settings.fadeOutSeconds) {
                    ForEach(AppSettings.fadeChoices, id: \.self) { seconds in
                        Text("\(seconds) s").tag(seconds)
                    }
                }
                .pickerStyle(.segmented)
                Text("How gently the sound fades at the end of a Focus or Sleep session.")
                    .font(.caption)
                    .foregroundStyle(.auraTextSecondary)
            }
        }
    }
}

/// The "Session alerts" switch. Turning it on asks iOS for permission the
/// first time; if notifications were blocked in iOS Settings, it says so
/// and links straight there. The status refreshes when you come back to
/// the app (e.g. after changing it in Settings).
struct NotificationSettingsRow: View {
    @Environment(SettingsController.self) private var settingsController
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    private var isBlocked: Bool {
        settingsController.notificationPermission == .denied
    }

    private var isOn: Binding<Bool> {
        Binding(
            get: { settingsController.settings.notificationsEnabled && !isBlocked },
            set: { newValue in
                Task { await settingsController.setNotificationsEnabled(newValue) }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsToggleRow(
                icon: "bell.badge.fill",
                tint: .auraRose,
                title: "Session alerts",
                subtitle: isBlocked
                    ? "Notifications are turned off for AuraSpatial in iOS Settings."
                    : "A notification when a Focus or Sleep session ends, even outside the app. Sleep alerts are silent.",
                isOn: isOn
            )
            .disabled(isBlocked)

            if isBlocked {
                Button {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Label("Open iOS Settings", systemImage: "arrow.up.forward.app")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.auraRose)
                }
                .buttonStyle(.plain)
                .padding(.leading, 42)
            }
        }
        .task {
            await settingsController.refreshNotificationPermission()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await settingsController.refreshNotificationPermission() }
            }
        }
    }
}

// MARK: - Account

/// How you sign in, and where to change your password.
struct AccountSection: View {
    let email: String
    let onChangePassword: () -> Void

    var body: some View {
        SettingsCard(title: "Account") {
            HStack(alignment: .top, spacing: 12) {
                SettingsIcon(systemImage: "envelope.fill", tint: .auraViolet)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Signed in with email")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.auraTextSecondary)
                }
            }

            SettingsDivider()
            SettingsActionRow(icon: "key.fill", title: "Change Password", isDestructive: false, action: onChangePassword)
        }
    }
}

// MARK: - Data & About

struct DataSection: View {
    let layoutCount: Int
    let onResetStats: () -> Void
    let onDeleteLayouts: () -> Void
    let onResetSettings: () -> Void

    var body: some View {
        SettingsCard(title: "Data & privacy") {
            HStack(alignment: .top, spacing: 12) {
                SettingsIcon(systemImage: Backend.isCloud ? "icloud.fill" : "iphone", tint: .auraTeal)
                VStack(alignment: .leading, spacing: 3) {
                    Text(Backend.storageTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("\(layoutCount.counted("saved layout")). \(Backend.storageDetail)")
                        .font(.caption)
                        .foregroundStyle(.auraTextSecondary)
                }
            }

            SettingsDivider()
            SettingsActionRow(icon: "chart.bar.xaxis", title: "Reset listening stats", action: onResetStats)
            SettingsDivider()
            SettingsActionRow(icon: "square.grid.2x2", title: "Delete all saved layouts", action: onDeleteLayouts)
            SettingsDivider()
            SettingsActionRow(icon: "arrow.counterclockwise", title: "Restore default settings", isDestructive: false, action: onResetSettings)
        }
    }
}

struct AboutSection: View {
    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        SettingsCard(title: "About") {
            aboutRow(title: "Version", value: versionText)
            SettingsDivider()
            aboutRow(title: "Audio engine", value: "AVAudioEngine · 3D")
            SettingsDivider()
            aboutRow(title: "Sounds", value: "Synthesized on-device")
            SettingsDivider()
            aboutRow(title: "Database", value: Backend.engineLabel)
            SettingsDivider()
            aboutRow(title: "Built with", value: "SwiftUI")
        }
    }

    private func aboutRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.auraTextSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Building blocks

/// A rounded card with a small heading above it.
struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: title)
            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.auraSurface, in: RoundedRectangle(cornerRadius: 18))
        }
    }
}

struct SettingsIcon: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
            .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Icon + title on the left, any control on the right.
struct SettingsRowLabel<Trailing: View>: View {
    let icon: String
    let tint: Color
    let title: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(systemImage: icon, tint: tint)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Spacer(minLength: 8)
            trailing
        }
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SettingsIcon(systemImage: icon, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.auraTextSecondary)
            }
            Spacer(minLength: 8)
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .tint(tint)
        }
    }
}

struct SettingsActionRow: View {
    let icon: String
    let title: String
    var isDestructive: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SettingsIcon(systemImage: icon, tint: isDestructive ? .auraDanger : .auraTextSecondary)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDestructive ? Color.auraDanger : Color.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.auraTextSecondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
    }
}
