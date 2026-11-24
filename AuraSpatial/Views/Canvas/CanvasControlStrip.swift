//
//  CanvasControlStrip.swift
//  AuraSpatial
//
//  The row of playback controls at the top of the Canvas (Play/Pause,
//  Orbit, Timer, sound count), the "session complete" banner, and the
//  live readout for the selected sound. Split out of CanvasView to keep
//  each view small (and quick for the compiler to type-check).
//

import SwiftUI

struct CanvasControlStrip: View {
    @Environment(CanvasController.self) private var canvasController
    let onTimerTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ControlChip(
                systemImage: canvasController.isPaused ? "play.fill" : "pause.fill",
                title: canvasController.isPaused ? "Play" : "Pause",
                tint: .auraViolet,
                isActive: canvasController.isPaused
            ) {
                canvasController.togglePause()
            }
            .disabled(canvasController.nodes.isEmpty)
            .opacity(canvasController.nodes.isEmpty ? 0.45 : 1)

            ControlChip(
                systemImage: "rotate.3d",
                title: "Orbit",
                tint: .auraTeal,
                isActive: canvasController.isOrbiting
            ) {
                withAnimation(.spring(duration: 0.3)) {
                    canvasController.toggleOrbit()
                }
            }

            timerChip

            Spacer(minLength: 0)

            Text("\(canvasController.nodes.count)/\(CanvasController.maxNodes)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.auraTextSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.auraSurface, in: Capsule())
                .accessibilityLabel("\(canvasController.nodes.count) of \(CanvasController.maxNodes) sounds placed")
        }
    }

    @ViewBuilder
    private var timerChip: some View {
        if let timer = canvasController.activeTimer {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                ControlChip(
                    systemImage: timer.mode.systemImage,
                    title: AuraFormat.countdown(timer.remaining(at: context.date)),
                    tint: timer.mode.tint,
                    isActive: true,
                    action: onTimerTap
                )
            }
        } else {
            ControlChip(
                systemImage: "timer",
                title: "Timer",
                tint: .auraAmber,
                isActive: false,
                action: onTimerTap
            )
        }
    }
}

/// One capsule button in the control strip. Fills with its tint when active.
struct ControlChip: View {
    let systemImage: String
    let title: String
    let tint: Color
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                Text(title)
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
            .foregroundStyle(isActive ? Color.white : tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(isActive ? tint.opacity(0.85) : tint.opacity(0.14))
            )
        }
        .buttonStyle(.plain)
    }
}

/// Shown after a Focus/Sleep timer ends and the Canvas has faded out.
struct SessionCompleteBanner: View {
    let mode: SessionMode
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: mode.systemImage)
                .foregroundStyle(mode.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(mode.completionTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Tap Play to pick up where you left off.")
                    .font(.caption)
                    .foregroundStyle(.auraTextSecondary)
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.auraTextSecondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(12)
        .background(Color.auraSurface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(mode.tint.opacity(0.3), lineWidth: 1))
    }
}

/// The live line above the Mix button: where the selected sound is and
/// how loud it reaches you. Updates continuously while you drag.
struct NodeReadoutView: View {
    let node: SoundNode
    let isSounding: Bool

    private var accentColor: Color {
        SoundAsset.resolve(node)?.category.accentColor ?? .auraViolet
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(accentColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(node.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(AuraFormat.meters(node.meters)) · \(node.directionLabel) · \(node.zone.label)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.auraTextSecondary)
            }
            Spacer(minLength: 8)
            LevelMeter(level: isSounding ? node.perceivedLevel : 0, color: accentColor)
            Text(isSounding ? AuraFormat.percent(node.perceivedLevel) : "Muted")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(isSounding ? accentColor : .auraTextSecondary)
                .frame(minWidth: 40, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.auraSurface.opacity(0.94), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(accentColor.opacity(0.25), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
