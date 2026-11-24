//
//  SoundNodeView.swift
//  AuraSpatial
//
//  One orbiting sound node on the Canvas - a reusable component (SRS
//  Section 3.1): a ring colored by the sound's category, a waveform glyph,
//  and the name + category label underneath.
//
//  The node now reflects what you hear: it grows and glows more the
//  louder it reaches the listener, and dims when paused or finished.
//  The labels sit in an overlay so the view's frame is exactly the
//  circle - its center is the point the beams and ripples are drawn from.
//
//  Advanced-technique note: when selected, the dashed "marching ants" ring
//  is tagged with `.matchedGeometryEffect` so it glides from one node to
//  another as selection changes, instead of just cross-fading.
//

import SwiftUI

struct SoundNodeView: View {
    let node: SoundNode
    let asset: SoundAsset?
    let isSelected: Bool
    /// Perceived level, 0...1.
    let level: Double
    let isSounding: Bool
    var namespace: Namespace.ID

    private var accentColor: Color {
        asset?.category.accentColor ?? .auraViolet
    }

    private var energy: Double {
        isSounding ? max(level, 0).squareRoot() : 0
    }

    var body: some View {
        ZStack {
            if isSelected {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        .foregroundStyle(accentColor)
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(timeline.date.timeIntervalSinceReferenceDate * 60))
                        .matchedGeometryEffect(id: "selectionRing", in: namespace)
                }
            }

            Circle()
                .stroke(accentColor.opacity(isSounding ? 1 : 0.45), lineWidth: 2)
                .background(Circle().fill(Color.auraSurface))
                .frame(width: 58, height: 58)
                .auraGlow(accentColor, radius: isSelected ? 12 : CGFloat(3 + 9 * energy))

            WaveformGlyph(color: accentColor.opacity(isSounding ? 1 : 0.5))
        }
        .frame(width: 72, height: 72)
        .scaleEffect(CGFloat(0.9 + 0.2 * energy))
        .overlay(alignment: .bottom) {
            labels
                .fixedSize()
                .offset(y: 30)
        }
        .opacity(isSounding ? 1 : 0.75)
        .animation(.spring(duration: 0.3), value: isSelected)
        .animation(.easeOut(duration: 0.2), value: isSounding)
        .contentShape(Circle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(node.displayName), \(node.directionLabel), \(AuraFormat.meters(node.meters))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var labels: some View {
        VStack(spacing: 1) {
            Text(node.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
            if let category = asset?.category {
                Text(category.label)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(accentColor)
            }
        }
    }
}
