//
//  SessionTimerView.swift
//  AuraSpatial
//
//  New screen: the Focus / Sleep session timer. Pick a mode and a length;
//  the Canvas keeps playing, a ring around the listener counts down, and
//  the sound fades out gently over the last few seconds (length set in
//  Profile > Settings). Finished sessions count toward the Profile stats,
//  and a local notification announces the end even outside the app.
//

import SwiftUI

struct SessionTimerView: View {
    @Environment(CanvasController.self) private var canvasController
    @Environment(SettingsController.self) private var settingsController
    @Environment(\.dismiss) private var dismiss

    @State private var mode: SessionMode = .focus
    @State private var minutes: Int = 30
    @State private var didLoadDefaults = false

    private let presets = AppSettings.timerChoices

    var body: some View {
        NavigationStack {
            ZStack {
                Color.auraBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        if let timer = canvasController.activeTimer {
                            RunningTimerPanel(timer: timer) {
                                canvasController.cancelTimer()
                            }
                        } else {
                            setupPanel
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Session Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.auraBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                guard !didLoadDefaults else { return }
                minutes = settingsController.settings.defaultTimerMinutes
                didLoadDefaults = true
            }
        }
    }

    private var setupPanel: some View {
        VStack(spacing: 24) {
            Picker("Mode", selection: $mode) {
                ForEach(SessionMode.allCases) { option in
                    Label(option.label, systemImage: option.systemImage).tag(option)
                }
            }
            .pickerStyle(.segmented)

            TimerDial(progress: 1, tint: mode.tint) {
                VStack(spacing: 2) {
                    Text("\(minutes)")
                        .font(.system(size: 54, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text("minutes")
                        .font(.subheadline)
                        .foregroundStyle(.auraTextSecondary)
                }
            }
            .animation(.spring(duration: 0.3), value: minutes)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 10)], spacing: 10) {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        minutes = preset
                    } label: {
                        Text("\(preset)m")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(preset == minutes ? mode.tint.opacity(0.85) : Color.auraSurface)
                            )
                            .foregroundStyle(preset == minutes ? Color.white : Color.auraTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(detailText)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.auraTextSecondary)

            Button {
                canvasController.startTimer(mode: mode, minutes: minutes)
                dismiss()
            } label: {
                Label("Start \(mode.label) Session", systemImage: mode.systemImage)
            }
            .buttonStyle(.primaryAura)
            .disabled(canvasController.nodes.isEmpty)
            .opacity(canvasController.nodes.isEmpty ? 0.5 : 1)

            if canvasController.nodes.isEmpty {
                Text("Add at least one sound to the canvas first.")
                    .font(.caption)
                    .foregroundStyle(.auraAmber)
            } else if let alertNote {
                Label(alertNote, systemImage: "bell.badge")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.auraTextSecondary)
            }
        }
        .task {
            await settingsController.refreshNotificationPermission()
        }
    }

    /// One line saying whether a notification will arrive at the end.
    private var alertNote: String? {
        guard settingsController.settings.notificationsEnabled else { return nil }
        switch settingsController.notificationPermission {
        case .allowed:
            return mode == .sleep
                ? "You'll get a silent notification when it ends."
                : "You'll get a notification when it ends, even outside the app."
        case .notDetermined:
            return "AuraSpatial will ask to notify you when the session ends."
        case .denied:
            return nil
        }
    }

    private var detailText: String {
        let fade = settingsController.settings.fadeOutSeconds
        switch mode {
        case .focus:
            return "Your soundscape plays for \(minutes) minutes, then fades out over \(fade) seconds so you know the session is over."
        case .sleep:
            return "Drift off to your soundscape. It fades out over the last \(fade) seconds and stops on its own."
        }
    }
}

/// Shown while a timer is running: a live countdown ring.
private struct RunningTimerPanel: View {
    let timer: SessionTimer
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Label("\(timer.mode.label) session running", systemImage: timer.mode.systemImage)
                .font(.headline)
                .foregroundStyle(timer.mode.tint)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                TimerDial(progress: timer.progress(at: context.date), tint: timer.mode.tint) {
                    VStack(spacing: 4) {
                        Text(AuraFormat.countdown(timer.remaining(at: context.date)))
                            .font(.system(size: 46, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                        Text("Ends at \(timer.endDate.formatted(date: .omitted, time: .shortened))")
                            .font(.subheadline)
                            .foregroundStyle(.auraTextSecondary)
                    }
                }
            }

            Button(role: .destructive, action: onCancel) {
                Text("Cancel Timer")
            }
            .buttonStyle(.secondaryAura)
        }
    }
}

/// A large progress ring with content in the middle.
private struct TimerDial<Content: View>: View {
    let progress: Double
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 14)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(tint, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .auraGlow(tint, radius: 10)
                .animation(.linear(duration: 1), value: progress)
            content
        }
        .frame(width: 220, height: 220)
        .padding(.vertical, 8)
    }
}
