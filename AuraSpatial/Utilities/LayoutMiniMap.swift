//
//  LayoutMiniMap.swift
//  AuraSpatial
//
//  A tiny drawing of a layout's ACTUAL arrangement - each sound as a dot
//  in its category color, at its real position around the listener.
//  Replaces the identical orbit icon every Saved / Community row used to
//  show, so each layout is recognizable at a glance.
//
//  Drawn with SwiftUI's immediate-mode `Canvas`, which is cheaper than
//  building a separate view per dot.
//

import SwiftUI

struct LayoutMiniMap: View {
    let nodes: [SoundNode]
    var size: CGFloat = 52

    private struct Dot {
        let x: Double
        let y: Double
        let color: Color
    }

    private var dots: [Dot] {
        nodes.map { node in
            let clamped = node.clampedToUnitCircle()
            let color = SoundAsset.resolve(node)?.category.accentColor ?? Color.auraViolet
            return Dot(x: clamped.x, y: clamped.y, color: color)
        }
    }

    var body: some View {
        let mapDots = self.dots
        let ringColor = Color.white.opacity(0.1)
        let listenerColor = Color.auraViolet
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = min(canvasSize.width, canvasSize.height) / 2 - 6

            for fraction in [1.0, 0.55] {
                let ringRadius = radius * CGFloat(fraction)
                let rect = CGRect(x: center.x - ringRadius, y: center.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2)
                context.stroke(Path(ellipseIn: rect), with: .color(ringColor), lineWidth: 1)
            }

            let listenerRect = CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)
            context.fill(Path(ellipseIn: listenerRect), with: .color(listenerColor))

            for dot in mapDots {
                let point = CGPoint(x: center.x + CGFloat(dot.x) * radius, y: center.y + CGFloat(dot.y) * radius)
                let halo = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
                context.fill(Path(ellipseIn: halo), with: .color(dot.color.opacity(0.25)))
                let core = CGRect(x: point.x - 2.5, y: point.y - 2.5, width: 5, height: 5)
                context.fill(Path(ellipseIn: core), with: .color(dot.color))
            }
        }
        .frame(width: size, height: size)
        .background(Color.auraSurfaceElevated, in: RoundedRectangle(cornerRadius: size * 0.28))
        .accessibilityLabel("Layout map with \(nodes.count.counted("sound"))")
    }
}

/// A row of small colored dots + counts: "● 3  ● 1  ● 2".
struct CategoryBreakdownView: View {
    let counts: [SoundCategory: Int]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(SoundCategory.allCases) { category in
                if let count = counts[category], count > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(category.accentColor)
                            .frame(width: 6, height: 6)
                        Text("\(count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.auraTextSecondary)
                    }
                    .accessibilityLabel("\(count) \(category.rawValue)")
                }
            }
        }
    }
}

#Preview {
    LayoutMiniMap(nodes: [
        SoundNode(soundAssetID: SoundAsset.library[0].id, displayName: "Rain", x: 0.4, y: -0.5),
        SoundNode(soundAssetID: SoundAsset.library[2].id, displayName: "Distant Thunder", x: -0.7, y: 0.2),
        SoundNode(soundAssetID: SoundAsset.library[4].id, displayName: "Campfire", x: 0.2, y: 0.6)
    ], size: 90)
    .padding(40)
    .background(Color.auraBackground)
}
