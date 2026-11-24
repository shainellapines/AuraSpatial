//
//  CanvasView.swift
//  AuraSpatial
//
//  Screen 4 (SRS Section 5): the Spatial Canvas - the core Place -> Position
//  loop. Tapping a node selects it (dashed ring + a live readout of its
//  distance, direction and level); tapping it again, or the Mix bar, opens
//  the Mixer. The background layers visualize the real audio: beams and
//  ripples scale with how loud each sound reaches you, and the colors tint
//  toward the categories in your mix.
//
//  New here: Save as layout (with a duplicate-name check), Play/Pause,
//  Orbit mode, the Focus/Sleep session timer, distance guides, an empty
//  state, and confirmation toasts.
//
//  Demonstrates PhaseAnimator, TimelineView + Canvas drawing,
//  matchedGeometryEffect, drag gestures, and .sensoryFeedback haptics.
//

import SwiftUI

struct CanvasView: View {
    @Environment(CanvasController.self) private var canvasController
    @Environment(SavedLayoutsController.self) private var savedLayoutsController
    @Environment(SettingsController.self) private var settingsController
    @Namespace private var canvasNamespace

    @State private var showingSoundLibrary = false
    @State private var showingTimer = false
    @State private var mixerNodeID: UUID?
    @State private var showingClearConfirmation = false
    @State private var isSelectionMode = false
    @State private var selectedForDeletion: Set<UUID> = []
    @State private var showingSaveAlert = false
    @State private var newLayoutName = ""
    @State private var duplicateLayout: Soundscape?
    @State private var pendingLayoutName = ""
    @State private var toastMessage: String?

    private var settings: AppSettings { settingsController.settings }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                canvasContent(in: proxy.size)
            }
            .background(Color.auraBackground.ignoresSafeArea())
            .navigationTitle("Canvas")
            .toolbarBackground(Color.auraBackground, for: .navigationBar)
            .toolbar { toolbarContent }
            .auraToast($toastMessage)
            .sensoryFeedback(.selection, trigger: canvasController.selectedNodeID) { _, _ in
                settings.hapticsEnabled
            }
            .sensoryFeedback(.success, trigger: canvasController.completedTimerMode) { _, newValue in
                settings.hapticsEnabled && newValue != nil
            }
            .confirmationDialog(
                "Clear Canvas",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All Sounds", role: .destructive) {
                    withAnimation {
                        canvasController.clearAll()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This removes every sound from the canvas. Saved layouts aren't affected.")
            }
            .alert("Save layout", isPresented: $showingSaveAlert) {
                TextField("Layout name", text: $newLayoutName)
                Button("Save") { attemptSave() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Saves the \(canvasController.nodes.count.counted("sound")) on your canvas, exactly where they are.")
            }
            .confirmationDialog(
                "“\(pendingLayoutName)” already exists",
                isPresented: duplicateBinding,
                titleVisibility: .visible,
                presenting: duplicateLayout
            ) { existing in
                Button("Replace It", role: .destructive) { replace(existing) }
                Button("Keep Both") {
                    save(as: savedLayoutsController.uniqueName(from: pendingLayoutName))
                }
                Button("Cancel", role: .cancel) { }
            } message: { _ in
                Text("Replace the saved layout, or save this one under a new name?")
            }
            .sheet(isPresented: $showingSoundLibrary) {
                SoundLibraryView(
                    placedAssetIDs: canvasController.placedAssetIDs,
                    remainingSlots: CanvasController.maxNodes - canvasController.nodes.count
                ) { asset in
                    withAnimation(.spring(duration: 0.35)) {
                        canvasController.addNode(from: asset)
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingTimer) {
                SessionTimerView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: mixerBinding) { node in
                MixerView(node: node)
                    .presentationDetents([.fraction(0.75), .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Canvas content

    @ViewBuilder
    private func canvasContent(in size: CGSize) -> some View {
        let layout = CanvasLayout(size: size)
        let fieldNodes = makeFieldNodes(layout: layout)
        let isAnimating = !fieldNodes.isEmpty && !canvasController.isPaused && !canvasController.isDucked

        ZStack {
            AmbientGlowLayer(nodes: fieldNodes, radius: layout.radius)

            DistanceGuidesView(
                center: layout.center,
                radius: layout.radius,
                showsLabels: settings.showDistanceGuides
            )

            if settings.showSoundWaves {
                SoundWavesLayer(nodes: fieldNodes, listener: layout.center, isActive: isAnimating)
            }

            ListenerAvatarView(timer: canvasController.activeTimer, isPaused: canvasController.isPaused)
                .position(layout.center)

            if canvasController.nodes.isEmpty {
                EmptyCanvasHint()
                    .position(x: layout.center.x, y: layout.center.y + min(layout.radius * 0.7, 130))
                    .transition(.opacity)
            }

            ForEach(canvasController.nodes) { node in
                nodeView(for: node, layout: layout)
            }

            overlayControls
        }
    }

    private func makeFieldNodes(layout: CanvasLayout) -> [FieldNode] {
        canvasController.nodes.map { node in
            FieldNode(
                id: node.id,
                point: layout.point(for: node),
                color: SoundAsset.resolve(node)?.category.accentColor ?? .auraViolet,
                level: node.perceivedLevel,
                isSounding: canvasController.isSounding(node)
            )
        }
    }

    private func nodeView(for node: SoundNode, layout: CanvasLayout) -> some View {
        SoundNodeView(
            node: node,
            asset: SoundAsset.resolve(node),
            isSelected: canvasController.selectedNodeID == node.id,
            level: node.perceivedLevel,
            isSounding: canvasController.isSounding(node),
            namespace: canvasNamespace
        )
        .overlay(alignment: .topTrailing) {
            if isSelectionMode {
                deletionBadge(for: node)
            }
        }
        .position(layout.point(for: node))
        .gesture(dragGesture(for: node, layout: layout))
        .onTapGesture {
            handleTap(on: node)
        }
    }

    private func dragGesture(for node: SoundNode, layout: CanvasLayout) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard !isSelectionMode else { return }
                if canvasController.selectedNodeID != node.id {
                    withAnimation(.spring(duration: 0.3)) {
                        canvasController.selectedNodeID = node.id
                    }
                }
                canvasController.beginDrag(id: node.id)
                canvasController.moveNode(
                    id: node.id,
                    to: value.location,
                    center: layout.center,
                    radius: layout.radius
                )
            }
            .onEnded { _ in
                canvasController.endDrag()
            }
    }

    private func handleTap(on node: SoundNode) {
        if isSelectionMode {
            toggleDeletion(node.id)
        } else if canvasController.selectedNodeID == node.id {
            mixerNodeID = node.id
        } else {
            withAnimation(.spring(duration: 0.3)) {
                canvasController.selectedNodeID = node.id
            }
        }
    }

    private func deletionBadge(for node: SoundNode) -> some View {
        let isMarked = selectedForDeletion.contains(node.id)
        return Button {
            toggleDeletion(node.id)
        } label: {
            Image(systemName: isMarked ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isMarked ? Color.auraDanger : Color.white)
                .background(Circle().fill(Color.auraBackground).padding(-4))
        }
        .offset(x: 4, y: -4)
        .transition(.scale.combined(with: .opacity))
    }

    private func toggleDeletion(_ id: UUID) {
        withAnimation(.spring(duration: 0.2)) {
            if selectedForDeletion.contains(id) {
                selectedForDeletion.remove(id)
            } else {
                selectedForDeletion.insert(id)
            }
        }
    }

    // MARK: - Overlaid controls

    private var overlayControls: some View {
        VStack(spacing: 10) {
            CanvasControlStrip(onTimerTap: { showingTimer = true })
                .padding(.horizontal, 20)
                .padding(.top, 6)

            if let mode = canvasController.completedTimerMode {
                SessionCompleteBanner(mode: mode) {
                    withAnimation { canvasController.dismissCompletedBanner() }
                }
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()

            if isSelectionMode {
                selectionToolbar
            } else {
                normalToolbar
            }
        }
        .animation(.spring(duration: 0.3), value: canvasController.selectedNodeID)
        .animation(.spring(duration: 0.3), value: isSelectionMode)
        .animation(.spring(duration: 0.3), value: canvasController.completedTimerMode)
    }

    private var normalToolbar: some View {
        VStack(spacing: 10) {
            if let selected = canvasController.node(with: canvasController.selectedNodeID) {
                NodeReadoutView(node: selected, isSounding: canvasController.isSounding(selected))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 12) {
                if let selected = canvasController.node(with: canvasController.selectedNodeID) {
                    Button {
                        mixerNodeID = selected.id
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Mix · \(selected.displayName)")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .buttonStyle(.primaryAura)
                    .fixedSize(horizontal: true, vertical: false)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }

                Spacer()

                Button {
                    showingSoundLibrary = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.floatingAura)
                .disabled(!canvasController.canAddNode)
                .opacity(canvasController.canAddNode ? 1 : 0.4)
                .accessibilityLabel(canvasController.canAddNode ? "Add sound" : "Canvas full")
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var selectionToolbar: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation {
                    if selectedForDeletion.count == canvasController.nodes.count {
                        selectedForDeletion.removeAll()
                    } else {
                        selectedForDeletion = Set(canvasController.nodes.map(\.id))
                    }
                }
            } label: {
                Text(selectedForDeletion.count == canvasController.nodes.count ? "Deselect All" : "Select All")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Spacer()

            Button {
                withAnimation {
                    for id in selectedForDeletion {
                        canvasController.removeNode(id: id)
                    }
                    selectedForDeletion.removeAll()
                    isSelectionMode = false
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                    Text("Delete (\(selectedForDeletion.count))")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.auraDanger)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(selectedForDeletion.isEmpty)
            .opacity(selectedForDeletion.isEmpty ? 0.5 : 1.0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if isSelectionMode {
                Button("Cancel") {
                    withAnimation {
                        isSelectionMode = false
                        selectedForDeletion.removeAll()
                    }
                }
                .foregroundStyle(.auraViolet)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    newLayoutName = canvasController.loadedLayoutName ?? ""
                    showingSaveAlert = true
                } label: {
                    Label("Save as Layout…", systemImage: "square.and.arrow.down")
                }

                Button {
                    withAnimation { isSelectionMode = true }
                } label: {
                    Label("Select Sounds", systemImage: "checkmark.circle")
                }

                Divider()

                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    Label("Clear All", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(canvasController.nodes.isEmpty ? Color.gray : Color.white)
            }
            .disabled(canvasController.nodes.isEmpty)
        }
    }

    // MARK: - Saving

    private var mixerBinding: Binding<SoundNode?> {
        Binding(
            get: { canvasController.node(with: mixerNodeID) },
            set: { mixerNodeID = $0?.id }
        )
    }

    private var duplicateBinding: Binding<Bool> {
        Binding(
            get: { duplicateLayout != nil },
            set: { isPresented in
                if !isPresented { duplicateLayout = nil }
            }
        )
    }

    private func attemptSave() {
        let trimmed = newLayoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Untitled Layout" : trimmed
        pendingLayoutName = name
        if let existing = savedLayoutsController.layout(named: name) {
            duplicateLayout = existing
        } else {
            save(as: name)
        }
    }

    private func save(as name: String) {
        let nodes = canvasController.nodes
        Task {
            let saved = await savedLayoutsController.saveNewLayout(name: name, nodes: nodes)
            canvasController.markSaved(as: saved)
            toastMessage = "Saved “\(saved.name)”"
        }
    }

    private func replace(_ existing: Soundscape) {
        let nodes = canvasController.nodes
        Task {
            let saved = await savedLayoutsController.overwrite(existing, with: nodes)
            canvasController.markSaved(as: saved)
            toastMessage = "Updated “\(saved.name)”"
        }
    }
}
