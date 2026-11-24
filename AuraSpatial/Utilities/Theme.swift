//
//  Theme.swift
//  AuraSpatial
//
//  Design tokens extracted directly from the live Figma Make prototype
//  (near-black background, violet/teal/amber accent system, glow treatment)
//  so the SwiftUI build is visually consistent with it, not just
//  structurally consistent. Kept in Utilities (the View layer's concern) so
//  Models stay pure Foundation/Codable with no SwiftUI import.
//

import SwiftUI

// Declared on `ShapeStyle where Self == Color` (rather than plain `Color`) so
// the leading-dot form resolves in `ShapeStyle` contexts too — e.g.
// `.foregroundStyle(.auraTextSecondary)` — while still being reachable as
// `Color.auraSurface` for `.fill`/`.background` and plain `Color` values.
extension ShapeStyle where Self == Color {
    /// Page background — near-black with the faintest violet cast.
    static var auraBackground: Color { Color(red: 0.031, green: 0.031, blue: 0.055) }
    /// Card/sheet surface, one step up from the background.
    static var auraSurface: Color { Color(red: 0.086, green: 0.086, blue: 0.125) }
    /// A slightly brighter surface for nested/elevated content.
    static var auraSurfaceElevated: Color { Color(red: 0.114, green: 0.114, blue: 0.157) }
    /// Primary brand accent — used for the listener, primary actions, and
    /// the "Ambient" sound category.
    static var auraViolet: Color { Color(red: 0.545, green: 0.486, blue: 0.988) }
    /// Secondary accent — the "Nature" sound category, and one of the two
    /// Community waveform tints.
    static var auraTeal: Color { Color(red: 0.204, green: 0.827, blue: 0.749) }
    /// Tertiary accent — the "Rhythm" sound category, and Community node-count pills.
    static var auraAmber: Color { Color(red: 0.937, green: 0.678, blue: 0.278) }
    /// Destructive actions.
    static var auraDanger: Color { Color(red: 0.914, green: 0.408, blue: 0.408) }
    /// Secondary text.
    static var auraTextSecondary: Color { Color(red: 0.635, green: 0.635, blue: 0.686) }
    /// A fourth accent, offered as a profile avatar color.
    static var auraRose: Color { Color(red: 0.957, green: 0.447, blue: 0.627) }
}

/// The three Sound Library categories seen in the prototype's canvas node
/// labels (NATURE / AMBIENT / RHYTHM), each with its own accent color.
extension SoundCategory {
    var accentColor: Color {
        switch self {
        case .nature: .auraTeal
        case .ambient: .auraViolet
        case .rhythm: .auraAmber
        }
    }
}

extension AvatarColor {
    var color: Color {
        switch self {
        case .violet: .auraViolet
        case .teal: .auraTeal
        case .amber: .auraAmber
        case .rose: .auraRose
        }
    }
}

extension SessionMode {
    var tint: Color {
        switch self {
        case .focus: .auraTeal
        case .sleep: .auraViolet
        }
    }
}

/// A soft, layered glow behind any view — used for the listener orb, the
/// floating add button, and selected/playing states throughout.
struct GlowModifier: ViewModifier {
    var color: Color
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.7), radius: radius * 0.5)
            .shadow(color: color.opacity(0.4), radius: radius)
    }
}

extension View {
    func auraGlow(_ color: Color, radius: CGFloat = 16) -> some View {
        modifier(GlowModifier(color: color, radius: radius))
    }

    /// The rounded, slightly heavier display font used for titles throughout
    /// the app, matching the prototype's headline treatment.
    func auraDisplayFont(_ size: CGFloat, weight: Font.Weight = .bold) -> some View {
        font(.system(size: size, weight: weight, design: .rounded))
    }
}
