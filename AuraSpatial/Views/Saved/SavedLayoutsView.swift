//
//  SavedLayoutsView.swift
//  AuraSpatial
//
//  Screen 7 (SRS Section 5): recall, overwrite, delete (FR-4.2).
//
//  Each row now shows a mini-map of the layout's real arrangement and a
//  category breakdown, marks the layout currently on the Canvas, and asks
//  before overwriting or deleting. Opening a layout jumps to the Canvas.
//  With Firebase, the ••• menu can also share a layout to the Community.
//

import SwiftUI

struct SavedLayoutsView: View {
    @Environment(SavedLayoutsController.self) private var savedLayoutsController
    @Environment(CanvasController.self) private var canvasController
    @Environment(AppRouter.self) private var router
    @Environment(CommunityController.self) private var communityController
    @Environment(AuthController.self) private var authController

    @State private var pendingOverwrite: Soundscape?
    @State private var pendingDelete: Soundscape?
    @State private var toastMessage: String?
    @State private var shareError: String?

    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.auraBackground.ignoresSafeArea()

                if savedLayoutsController.savedLayouts.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("\(savedLayoutsController.savedLayouts.count.counted("layout")) · tap one to open it on the Canvas")
                                .font(.caption)
                                .foregroundStyle(.auraTextSecondary)
                                .padding(.horizontal, 4)

                            ForEach(savedLayoutsController.savedLayouts) { layout in
                                SavedLayoutRow(
                                    layout: layout,
                                    updatedText: relativeFormatter.localizedString(for: layout.updatedAt, relativeTo: Date()),
                                    isOnCanvas: canvasController.loadedLayoutID == layout.id,
                                    canShare: communityController.canShare,
                                    onOpen: { open(layout) },
                                    onOverwrite: { pendingOverwrite = layout },
                                    onShare: { share(layout) },
                                    onDelete: { pendingDelete = layout }
                                )
                            }
                        }
                        .padding(20)
                    }
                    .refreshable {
                        await savedLayoutsController.refresh()
                    }
                }
            }
            .navigationTitle("Saved Layouts")
            .toolbarBackground(Color.auraBackground, for: .navigationBar)
            .auraToast($toastMessage)
            .alert("Couldn't share", isPresented: shareErrorBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(shareError ?? "")
            }
            .confirmationDialog(
                "Overwrite this layout?",
                isPresented: isPresenting($pendingOverwrite),
                titleVisibility: .visible,
                presenting: pendingOverwrite
            ) { layout in
                if !canvasController.nodes.isEmpty {
                    Button("Overwrite “\(layout.name)”", role: .destructive) {
                        overwrite(layout)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: { layout in
                if canvasController.nodes.isEmpty {
                    Text("Your canvas is empty. Add sounds to the canvas first, then overwrite.")
                } else {
                    Text("“\(layout.name)” will be replaced with the \(canvasController.nodes.count.counted("sound")) currently on your canvas.")
                }
            }
            .confirmationDialog(
                "Delete this layout?",
                isPresented: isPresenting($pendingDelete),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { layout in
                Button("Delete “\(layout.name)”", role: .destructive) {
                    Task { await savedLayoutsController.delete(layout) }
                }
                Button("Cancel", role: .cancel) { }
            } message: { _ in
                Text("This can't be undone.")
            }
            .task {
                await savedLayoutsController.refresh()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            OrbitGlyph(size: 90)
            Text("No saved layouts yet")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Arrange sounds on the Canvas, then choose\nSave as Layout from the ••• menu.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.auraTextSecondary)
            Button("Go to Canvas") {
                router.selectedTab = .canvas
            }
            .buttonStyle(.primaryAura)
            .fixedSize()
            .padding(.top, 6)
        }
        .padding(32)
    }

    private func open(_ layout: Soundscape) {
        canvasController.loadLayout(layout)
        router.selectedTab = .canvas
    }

    private func overwrite(_ layout: Soundscape) {
        let nodes = canvasController.nodes
        Task {
            let updated = await savedLayoutsController.overwrite(layout, with: nodes)
            canvasController.markSaved(as: updated)
            toastMessage = "Updated “\(updated.name)”"
        }
    }

    private func share(_ layout: Soundscape) {
        let username = authController.currentUser?.username ?? "listener"
        Task {
            do {
                try await communityController.share(layout, as: username)
                toastMessage = "Shared “\(layout.name)” to Community"
            } catch {
                shareError = error.localizedDescription
            }
        }
    }

    private var shareErrorBinding: Binding<Bool> {
        Binding(
            get: { shareError != nil },
            set: { isPresented in
                if !isPresented { shareError = nil }
            }
        )
    }

    /// Turns an optional "pending" item into the Bool a dialog needs.
    private func isPresenting(_ item: Binding<Soundscape?>) -> Binding<Bool> {
        Binding(
            get: { item.wrappedValue != nil },
            set: { isPresented in
                if !isPresented { item.wrappedValue = nil }
            }
        )
    }
}

/// One saved layout. Tapping the row opens it; the ••• menu overwrites,
/// shares (with Firebase), or deletes it.
private struct SavedLayoutRow: View {
    let layout: Soundscape
    let updatedText: String
    let isOnCanvas: Bool
    let canShare: Bool
    let onOpen: () -> Void
    let onOverwrite: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onOpen) {
                HStack(spacing: 14) {
                    LayoutMiniMap(nodes: layout.nodes, size: 56)
                    details
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens this layout on the Canvas")

            VStack(alignment: .trailing, spacing: 8) {
                PillBadge(text: layout.nodes.count.counted("sound"), color: .auraViolet)
                actionsMenu
            }
        }
        .padding(16)
        .background(Color.auraSurface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isOnCanvas ? Color.auraTeal.opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(layout.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if isOnCanvas {
                    PillBadge(text: "On canvas", color: .auraTeal, filled: false)
                }
            }
            Text("Updated \(updatedText)")
                .font(.caption)
                .foregroundStyle(.auraTextSecondary)
            CategoryBreakdownView(counts: layout.categoryCounts)
        }
    }

    private var actionsMenu: some View {
        Menu {
            Button(action: onOverwrite) {
                Label("Overwrite with Canvas", systemImage: "arrow.triangle.2.circlepath")
            }
            if canShare {
                Button(action: onShare) {
                    Label("Share to Community", systemImage: "person.2.wave.2")
                }
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityLabel("Layout actions")
    }
}
