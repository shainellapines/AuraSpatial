//
//  SpatialFieldView.swift
//  AuraSpatial
//
//  The layers drawn behind the sound nodes on the Canvas. Each one shows
//  REAL audio data rather than decoration:
//
//  - AmbientGlowLayer: a soft blur of each sound's category color, so a
//    rain-heavy mix tints teal and a campfire mix tints amber.
//  - DistanceGuidesView: Near / Mid / Far rings (the same thresholds the
//    readout uses) and Front / Back / L / R around the listener.
//  - SoundWavesLayer: a beam from each sound to the listener whose
//    brightness and width match how loud you actually hear it, ripples
//    that pulse faster for louder sounds, and pulses traveling inward.
//
//  The animated layers use TimelineView + the immediate-mode `Canvas`
//  (one draw pass per frame instead of dozens of animated views), and
//  pause themselves when nothing is playing.
//

import SwiftUI

/// Everything a background layer needs to know about one node, already
/// converted to screen points and colors.
struct FieldNode: Identifiable, Equatable {
    let id: UUID
    let point: CGPoint
    let color: Color
    /// Perceived level, 0...1 (volume x distance attenuation).
    let level: Double
    let isSounding: Bool

    /// A square-root curve so far-away sounds still show some motion.
    var energy: Double {
        isSounding ? max(level, 0).squareRoot() : 0
    }
}

/// Where the listener sits and how big the outer ring is, for a given
/// canvas size. Both drawing and dragging use this, so a node always
/// stays exactly under the finger.
struct CanvasLayout {
    let center: CGPoint
    let radius: CGFloat

    init(size: CGSize) {
        let topInset: CGFloat = 64
        let bottomInset: CGFloat = 150
        let usableHeight = max(size.height - topInset - bottomInset, 160)
        center = CGPoint(x: size.width / 2, y: topInset + usableHeight / 2)
        radius = max(70, min(size.width / 2 - 44, usableHeight / 2 - 22))
    }

    func point(for node: SoundNode) -> CGPoint {
        CGPoint(
            x: center.x + CGFloat(node.x) * radius,
            y: center.y + CGFloat(node.y) * radius
        )
    }
}

// MARK: - Ambient glow

struct AmbientGlowLayer: View {
    let nodes: [FieldNode]
    let radius: CGFloat

    var body: some View {
        let glowSize = radius * 1.2
        Canvas { context, _ in
            context.addFilter(.blur(radius: 48))
            for node in nodes {
                let strength = node.isSounding ? 0.12 + 0.3 * node.energy : 0.05
                let rect = CGRect(
                    x: node.point.x - glowSize / 2,
                    y: node.point.y - glowSize / 2,
                    width: glowSize,
                    height: glowSize
                )
                context.fill(Path(ellipseIn: rect), with: .color(node.color.opacity(strength)))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Distance guides

struct DistanceGuidesView: View {
    let center: CGPoint
    let radius: CGFloat
    let showsLabels: Bool

    var body: some View {
        ZStack {
            crosshair

            ForEach(DistanceZone.allCases) { zone in
                ring(for: zone)
            }

            if showsLabels {
                ForEach(DistanceZone.allCases) { zone in
                    zoneLabel(for: zone)
                }
                compassLabel("FRONT", x: center.x, y: center.y - radius - 16)
                compassLabel("BACK", x: center.x, y: center.y + radius + 16)
                compassLabel("L", x: center.x - radius - 16, y: center.y)
                compassLabel("R", x: center.x + radius + 16, y: center.y)
            }
        }
        .allowsHitTesting(false)
    }

    private var crosshair: some View {
        Path { path in
            path.move(to: CGPoint(x: center.x - radius, y: center.y))
            path.addLine(to: CGPoint(x: center.x + radius, y: center.y))
            path.move(to: CGPoint(x: center.x, y: center.y - radius))
            path.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        }
        .stroke(Color.white.opacity(0.04), lineWidth: 1)
    }

    private func ring(for zone: DistanceZone) -> some View {
        let ringRadius = radius * CGFloat(zone.outerRadius)
        let isOuter = zone == .far
        return Circle()
            .stroke(
                Color.white.opacity(isOuter ? 0.10 : 0.06),
                style: StrokeStyle(lineWidth: 1, dash: isOuter ? [] : [3, 5])
            )
            .frame(width: ringRadius * 2, height: ringRadius * 2)
            .position(center)
    }

    private func zoneLabel(for zone: DistanceZone) -> some View {
        let ringRadius = radius * CGFloat(zone.outerRadius)
        let offset = ringRadius * 0.707
        return Text(zone.label.uppercased())
            .font(.system(size: 8, weight: .bold))
            .tracking(1)
            .foregroundStyle(Color.white.opacity(0.28))
            .position(x: center.x + offset + 6, y: center.y - offset - 6)
    }

    private func compassLabel(_ text: String, x: CGFloat, y: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy))
            .tracking(1.2)
            .foregroundStyle(Color.white.opacity(0.35))
            .position(x: x, y: y)
    }
}

// MARK: - Sound waves

struct SoundWavesLayer: View {
    let nodes: [FieldNode]
    let listener: CGPoint
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isActive)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, _ in
                for (index, node) in nodes.enumerated() {
                    SoundWavesLayer.drawBeam(for: node, listener: listener, in: &context)
                    if node.isSounding {
                        SoundWavesLayer.drawRipples(for: node, index: index, time: time, in: &context)
                        SoundWavesLayer.drawPulses(for: node, index: index, time: time, listener: listener, in: &context)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// The line from sound to listener. Brighter and thicker = louder.
    private static func drawBeam(for node: FieldNode, listener: CGPoint, in context: inout GraphicsContext) {
        var beam = Path()
        beam.move(to: node.point)
        beam.addLine(to: listener)
        let energy = node.energy
        let startOpacity = node.isSounding ? 0.08 + energy * 0.5 : 0.08
        let gradient = Gradient(colors: [node.color.opacity(startOpacity), node.color.opacity(0.03)])
        let style = StrokeStyle(
            lineWidth: CGFloat(1 + energy * 2.5),
            lineCap: .round,
            dash: node.isSounding ? [] : [2, 5]
        )
        context.stroke(
            beam,
            with: .linearGradient(gradient, startPoint: node.point, endPoint: listener),
            style: style
        )
    }

    /// Rings spreading out from the sound. Faster and brighter = louder.
    private static func drawRipples(for node: FieldNode, index: Int, time: Double, in context: inout GraphicsContext) {
        let energy = node.energy
        let speed = 0.25 + energy * 0.75
        for ring in 0..<3 {
            let raw = time * speed + Double(ring) / 3 + Double(index) * 0.17
            let phase = raw - raw.rounded(.down)
            let rippleRadius = CGFloat(32 + phase * (30 + energy * 34))
            let rect = CGRect(
                x: node.point.x - rippleRadius,
                y: node.point.y - rippleRadius,
                width: rippleRadius * 2,
                height: rippleRadius * 2
            )
            let opacity = (1 - phase) * (0.12 + energy * 0.45)
            context.stroke(Path(ellipseIn: rect), with: .color(node.color.opacity(opacity)), lineWidth: 1.2)
        }
    }

    /// Small dots traveling along the beam into the listener.
    private static func drawPulses(for node: FieldNode, index: Int, time: Double, listener: CGPoint, in context: inout GraphicsContext) {
        let energy = node.energy
        let dx = listener.x - node.point.x
        let dy = listener.y - node.point.y
        for pulse in 0..<2 {
            let raw = time * (0.3 + energy * 0.6) + Double(pulse) * 0.5 + Double(index) * 0.23
            let progress = raw - raw.rounded(.down)
            let x = node.point.x + dx * CGFloat(progress)
            let y = node.point.y + dy * CGFloat(progress)
            let dotSize = CGFloat(2.5 + energy * 3)
            let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
            let opacity = (1 - progress * 0.7) * (0.25 + energy * 0.6)
            context.fill(Path(ellipseIn: rect), with: .color(node.color.opacity(opacity)))
        }
    }
}

// MARK: - Listener

/// The fixed listener at the center. Pulses gently, shows a pause icon
/// when paused, a small "front" chevron, and - when a session timer is
/// running - a ring that empties as the time runs down.
struct ListenerAvatarView: View {
    let timer: SessionTimer?
    let isPaused: Bool

    var body: some View {
        ZStack {
            PhaseAnimator([false, true]) { expanded in
                ZStack {
                    Circle()
                        .fill(Color.auraViolet.opacity(isPaused ? 0.1 : 0.25))
                        .frame(width: expanded ? 110 : 80, height: expanded ? 110 : 80)
                        .blur(radius: 8)
                    Circle()
                        .fill(Color.auraViolet)
                        .frame(width: 56, height: 56)
                        .auraGlow(.auraViolet, radius: isPaused ? 8 : 18)
                    Image(systemName: isPaused ? "pause.fill" : "person.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
            } animation: { _ in
                .easeInOut(duration: 1.8)
            }

            if let timer {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    TimerRing(progress: timer.progress(at: context.date), tint: timer.mode.tint)
                }
            }

            Image(systemName: "chevron.up")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.55))
                .offset(y: -48)
        }
        .frame(width: 110, height: 110)
        .allowsHitTesting(false)
    }
}

private struct TimerRing: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
        }
        .frame(width: 78, height: 78)
    }
}

// MARK: - Empty state

struct EmptyCanvasHint: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("Your space is quiet")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Tap + to place your first sound,\nthen drag it closer or farther.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.auraTextSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.auraSurface.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
        .allowsHitTesting(false)
    }
}
