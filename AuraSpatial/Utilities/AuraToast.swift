//
//  AuraToast.swift
//  AuraSpatial
//
//  A short confirmation that slides in from the top and disappears on its
//  own ("Saved “Rainy Night”"), plus a small level meter used by the
//  Canvas readout and the Mixer.
//

import SwiftUI

struct AuraToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.auraTeal)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.auraSurfaceElevated, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.4), radius: 12, y: 6)
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let current = message {
                    AuraToast(message: current)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task(id: current) {
                            try? await Task.sleep(for: .seconds(2.2))
                            if message == current {
                                message = nil
                            }
                        }
                }
            }
            .animation(.spring(duration: 0.35), value: message)
    }
}

extension View {
    /// Shows `message` as a toast; set it to a string to show one.
    func auraToast(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}

/// Five bars that fill with a sound's level (uses a square-root curve so
/// quiet, far-away sounds still register visually).
struct LevelMeter: View {
    let level: Double
    var color: Color = .auraViolet
    var barCount: Int = 5

    private var litBars: Int {
        let visual = max(level, 0).squareRoot()
        return min(barCount, Int((visual * Double(barCount)).rounded(.up)))
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < litBars ? color : Color.white.opacity(0.12))
                    .frame(width: 3, height: 5 + CGFloat(index) * 2.5)
            }
        }
        .accessibilityLabel("Level \(AuraFormat.percent(level))")
    }
}
