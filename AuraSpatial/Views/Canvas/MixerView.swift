//
//  MixerView.swift
//  AuraSpatial
//
//  Screen 6 (SRS Section 5): the Granular Mixer sheet - fine control over
//  one node, independent of its canvas position.
//
//  Every control now changes the sound LIVE as you move it:
//  - Volume sets the node's gain.
//  - Pan nudges the sound left/right on top of where it sits.
//  - Loop off plays the sound once; "Play again" re-triggers it.
//  The top row shows where the sound is and how loud it reaches you.
//

import SwiftUI

struct MixerView: View {
    @Environment(CanvasController.self) private var canvasController
    @Environment(\.dismiss) private var dismiss

    @State private var volume: Double
    @State private var panBias: Double
    @State private var isLooping: Bool

    private let nodeID: UUID
    private let initialNode: SoundNode

    init(node: SoundNode) {
        self.nodeID = node.id
        self.initialNode = node
        _volume = State(initialValue: node.volumeBias)
        _panBias = State(initialValue: node.panBias)
        _isLooping = State(initialValue: node.isLooping)
    }

    /// The node as it is right now (it can move while Orbit is on).
    private var node: SoundNode {
        canvasController.node(with: nodeID) ?? initialNode
    }

    private var asset: SoundAsset? {
        SoundAsset.resolve(node)
    }

    private var accentColor: Color {
        asset?.category.accentColor ?? .auraViolet
    }

    private var isFinished: Bool {
        canvasController.finishedNodeIDs.contains(nodeID)
    }

    var body: some View {
        ZStack {
            Color.auraBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    statsRow
                    controls
                    actions
                }
                .padding(24)
            }
        }
        .onChange(of: volume) { _, newValue in
            canvasController.setVolume(newValue, for: nodeID)
        }
        .onChange(of: panBias) { _, newValue in
            canvasController.setPan(newValue, for: nodeID)
        }
        .onChange(of: isLooping) { _, newValue in
            canvasController.setLooping(newValue, for: nodeID)
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: asset?.systemImageName ?? "waveform")
                    .font(.title3)
                    .foregroundStyle(accentColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(node.displayName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                if let asset {
                    Text(asset.category.label)
                        .font(.caption.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(accentColor)
                    Text(asset.summary)
                        .font(.caption)
                        .foregroundStyle(.auraTextSecondary)
                }
            }
            Spacer()
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            MixerStatTile(title: "Distance", value: AuraFormat.meters(node.meters), detail: node.zone.label)
            MixerStatTile(title: "Direction", value: node.directionLabel, detail: "from you")
            MixerStatTile(
                title: "You hear",
                value: canvasController.isSounding(node) ? AuraFormat.percent(node.perceivedLevel) : "—",
                detail: canvasController.isSounding(node) ? "of full volume" : "not playing",
                tint: accentColor
            )
        }
    }

    private var controls: some View {
        VStack(spacing: 18) {
            sliderRow(
                icon: "speaker.wave.2.fill",
                label: "Volume",
                value: $volume,
                range: 0...1,
                valueText: AuraFormat.percent(volume)
            )
            sliderRow(
                icon: "arrow.left.arrow.right",
                label: "Pan",
                value: $panBias,
                range: -1...1,
                valueText: AuraFormat.pan(panBias)
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "repeat")
                        .foregroundStyle(.auraTextSecondary)
                    Text("Loop")
                        .foregroundStyle(.white)
                    Spacer()
                    Toggle("Loop", isOn: $isLooping)
                        .labelsHidden()
                        .tint(accentColor)
                }
                Text(isLooping ? "Repeats seamlessly." : "Plays once, then goes quiet.")
                    .font(.caption)
                    .foregroundStyle(.auraTextSecondary)
            }

            if !isLooping {
                Button {
                    canvasController.replay(id: nodeID)
                } label: {
                    Label(isFinished ? "Play Again" : "Restart", systemImage: "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(accentColor)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(16)
        .background(Color.auraSurface, in: RoundedRectangle(cornerRadius: 18))
        .animation(.easeInOut(duration: 0.2), value: isLooping)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.primaryAura)

            Button(role: .destructive) {
                canvasController.removeNode(id: nodeID)
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                    Text("Remove Sound")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.auraDanger.opacity(0.15))
                .foregroundStyle(.auraDanger)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func sliderRow(icon: String, label: String, value: Binding<Double>, range: ClosedRange<Double>, valueText: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.auraTextSecondary)
                Text(label)
                    .foregroundStyle(.white)
                Spacer()
                Text(valueText)
                    .foregroundStyle(accentColor)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            }
            Slider(value: value, in: range)
                .tint(accentColor)
        }
    }
}

/// One small stat box in the Mixer's top row.
private struct MixerStatTile: View {
    let title: String
    let value: String
    let detail: String
    var tint: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.auraTextSecondary)
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.auraTextSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.auraSurface, in: RoundedRectangle(cornerRadius: 14))
    }
}
