//
//  SoundLibraryView.swift
//  AuraSpatial
//
//  Screen 5 (SRS Section 5): the catalog nodes are added from (FR-2.3).
//  Now with category filter chips, a one-line description per sound, an
//  "On canvas" marker for sounds already placed, and a clear message when
//  the canvas is full.
//

import SwiftUI

struct SoundLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    let placedAssetIDs: Set<UUID>
    let remainingSlots: Int
    let onSelect: (SoundAsset) -> Void

    @State private var filter: SoundCategory?

    private var visibleAssets: [SoundAsset] {
        guard let filter else { return SoundAsset.library }
        return SoundAsset.library.filter { $0.category == filter }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.auraBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        filterChips

                        Text(remainingSlots > 0
                             ? "\(remainingSlots.counted("slot")) left on your canvas"
                             : "Your canvas is full. Remove a sound to add another.")
                            .font(.caption)
                            .foregroundStyle(remainingSlots > 0 ? Color.auraTextSecondary : Color.auraAmber)

                        VStack(spacing: 12) {
                            ForEach(visibleAssets) { asset in
                                SoundLibraryRow(
                                    asset: asset,
                                    isOnCanvas: placedAssetIDs.contains(asset.id),
                                    isEnabled: remainingSlots > 0
                                ) {
                                    onSelect(asset)
                                    dismiss()
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Sound Library")
            .toolbarBackground(Color.auraBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", color: .auraViolet, isSelected: filter == nil) {
                    filter = nil
                }
                ForEach(SoundCategory.allCases) { category in
                    FilterChip(title: category.rawValue, color: category.accentColor, isSelected: filter == category) {
                        filter = category
                    }
                }
            }
        }
        .animation(.spring(duration: 0.25), value: filter)
    }
}

private struct FilterChip: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(isSelected ? color.opacity(0.85) : Color.auraSurface))
                .foregroundStyle(isSelected ? Color.white : Color.auraTextSecondary)
        }
        .buttonStyle(.plain)
    }
}

/// One row in the library. Extracted so the list body stays simple to
/// type-check.
private struct SoundLibraryRow: View {
    let asset: SoundAsset
    let isOnCanvas: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(asset.category.accentColor.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: asset.systemImageName)
                        .foregroundStyle(asset.category.accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(asset.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        if isOnCanvas {
                            PillBadge(text: "On canvas", color: asset.category.accentColor, filled: false)
                        }
                    }
                    Text(asset.summary)
                        .font(.caption)
                        .foregroundStyle(.auraTextSecondary)
                    Text(asset.category.label)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(asset.category.accentColor)
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.auraViolet)
                    .font(.title3)
            }
            .padding(14)
            .background(Color.auraSurface, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}
