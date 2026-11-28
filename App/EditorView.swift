import SwiftUI

/// The widget editor: a live canvas on top, tools and properties underneath.
struct EditorView: View {
    @StateObject private var model: EditorModel
    @State private var showBackground = false
    @State private var showLayers = false
    @State private var showRename = false
    @State private var showCodeEditor = false
    @State private var draftName = ""
    @State private var shareFile: ShareFile?
    @State private var shareError: String?

    init(design: WidgetDesign, library: DesignLibrary) {
        _model = StateObject(wrappedValue: EditorModel(design: design, persist: { updated in
            library.persist(updated)
        }))
    }

    var body: some View {
        GeometryReader { outer in
            let panelHeight = resolvedPanelHeight(available: outer.size.height)
            VStack(spacing: 0) {
                canvasArea
                    .frame(height: max(0, outer.size.height - panelHeight - 1))
                Divider()
                bottomPanel
                    .frame(maxWidth: .infinity)
                    .frame(height: panelHeight)
                    .background(Color(.secondarySystemGroupedBackground))
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(model.design.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onChange(of: model.selection) { _, newValue in
            if newValue != nil {
                showBackground = false
            }
        }
        .onDisappear {
            model.flush()
        }
        .sheet(isPresented: $showLayers) {
            LayersView(model: model)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCodeEditor) {
            CodeEditorView(model: model)
        }
        .sheet(item: $shareFile) { file in
            ActivityView(items: [file.url])
        }
        .alert("Rename Widget", isPresented: $showRename) {
            TextField("Name", text: $draftName)
            Button("Save") {
                model.rename(to: draftName)
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Couldn't Share", isPresented: shareErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(shareError ?? "")
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

    private func share() {
        model.flush()
        do {
            shareFile = ShareFile(url: try DesignExchange.exportFile(model.design))
        } catch {
            shareError = error.localizedDescription
        }
    }

    // MARK: Layout

    /// The tools panel is taller while editing something, but always leaves room for the canvas.
    private func resolvedPanelHeight(available: CGFloat) -> CGFloat {
        let wanted: CGFloat = (showBackground || model.selection != nil) ? 320 : 176
        return min(wanted, max(150, available - 190))
    }

    private var canvasArea: some View {
        GeometryReader { geo in
            let aspect = model.design.size.aspectRatio
            let maxWidth = max(80, geo.size.width - 48)
            let maxHeight = max(80, geo.size.height - 48)
            let width = min(maxWidth, maxHeight * aspect)
            let size = CGSize(width: width, height: width / aspect)
            canvas(size: size)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func canvas(size: CGSize) -> some View {
        let reference = model.design.size.referenceSize
        let scale = size.width / reference.width
        return ZStack {
            TimelineView(.periodic(from: .now, by: 20)) { context in
                DesignCanvasView(design: model.design, date: context.date)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 22 * scale, style: .continuous))
            .shadow(color: Color.black.opacity(0.25), radius: 14, x: 0, y: 6)
            .allowsHitTesting(false)

            if !model.isPreviewing {
                CanvasInteractionLayer(model: model, canvas: size)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder private var bottomPanel: some View {
        if showBackground {
            BackgroundPanel(model: model) {
                showBackground = false
            }
        } else if let element = model.selectedElement {
            InspectorPanel(model: model, element: element)
        } else {
            AddPanel(
                model: model,
                onBackground: { showBackground = true },
                onLayers: { showLayers = true }
            )
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                model.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!model.canUndo)

            Button {
                model.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!model.canRedo)

            Button {
                model.isPreviewing.toggle()
                model.selection = nil
            } label: {
                Image(systemName: model.isPreviewing ? "eye.slash" : "eye")
            }

            Menu {
                Button {
                    draftName = model.design.name
                    showRename = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Button {
                    showLayers = true
                } label: {
                    Label("Layers", systemImage: "square.3.layers.3d")
                }
                Button {
                    model.selection = nil
                    showBackground = true
                } label: {
                    Label("Background", systemImage: "paintpalette")
                }
                Divider()
                Button {
                    share()
                } label: {
                    Label("Share…", systemImage: "square.and.arrow.up")
                }
                Button {
                    showCodeEditor = true
                } label: {
                    Label("View/Edit Code", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}
