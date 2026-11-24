//
//  CommunitySoundscapeCardView.swift
//  AuraSpatial
//
//  One Community Feed card - a reusable component (SRS Section 3.1): an
//  animated waveform behind a play/pause button, then a footer with a
//  mini-map of the layout's real arrangement, its category breakdown,
//  likes, and Fork.
//
//  The tint now comes from the layout's dominant sound category instead
//  of `hashValue` (which changes every launch).
//

import SwiftUI

struct CommunitySoundscapeCardView: View {
    let soundscape: Soundscape
    let isPlaying: Bool
    let isLiked: Bool
    let likeCount: Int
    let onPlayToggle: () -> Void
    let onLike: () -> Void
    let onFork: () -> Void

    @State private var didFork = false

    private var tint: Color {
        soundscape.dominantCategory?.accentColor ?? .auraViolet
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                AnimatedWaveformBackground(tint: tint, isPlaying: isPlaying)
                    .padding(.horizontal, 16)

                Button(action: onPlayToggle) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(tint.opacity(0.9), in: Circle())
                        .auraGlow(tint, radius: isPlaying ? 14 : 0)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? "Stop preview" : "Play preview")

                if isPlaying {
                    Text("PLAYING IN 3D")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.auraBackground.opacity(0.7), in: Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(10)
                        .transition(.opacity)
                }
            }
            .frame(height: 84)
            .background(Color.auraSurfaceElevated)
            .animation(.easeInOut(duration: 0.2), value: isPlaying)

            HStack(alignment: .top, spacing: 14) {
                LayoutMiniMap(nodes: soundscape.nodes, size: 58)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(soundscape.name)
                                .font(.headline)
                                .foregroundStyle(.white)
                            if let creator = soundscape.creatorUsername {
                                Text("@\(creator)")
                                    .font(.caption)
                                    .foregroundStyle(.auraTextSecondary)
                            }
                        }
                        Spacer()
                        PillBadge(text: soundscape.nodes.count.counted("sound"), color: .auraAmber)
                    }

                    CategoryBreakdownView(counts: soundscape.categoryCounts)

                    HStack(spacing: 16) {
                        Button(action: onLike) {
                            Label("\(likeCount)", systemImage: isLiked ? "heart.fill" : "heart")
                                .foregroundStyle(isLiked ? Color.auraRose : Color.auraTextSecondary)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isLiked ? "Unlike" : "Like")

                        Label("\(soundscape.forkCount)", systemImage: "arrow.triangle.branch")

                        Spacer()

                        Button {
                            onFork()
                            withAnimation(.spring(duration: 0.3)) { didFork = true }
                        } label: {
                            Label(didFork ? "Forked" : "Fork", systemImage: didFork ? "checkmark" : "arrow.triangle.branch")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(didFork ? Color.auraTeal : Color.auraViolet)
                    }
                    .font(.caption)
                    .foregroundStyle(.auraTextSecondary)
                }
            }
            .padding(16)
            .background(Color.auraSurface)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isPlaying ? tint.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
}
