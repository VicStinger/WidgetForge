import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Home screen of the app: every design you've made, grouped by widget size.
struct DesignLibraryView: View {
    @EnvironmentObject private var library: DesignLibrary

    @State private var showNew = false
    @State private var showGenerate = false
    @State private var showImporter = false
    @State private var showPasteCode = false
    @State private var showHelp = false
    @State private var showCredits = false
    @State private var renaming: WidgetDesign?
    @State private var renameText = ""
    @State private var pendingDelete: WidgetDesign?
    @State private var copiedCode = false
    @State private var shareFile: ShareFile?
    @State private var shareError: String?

    var body: some View {
        NavigationStack(path: $library.path) {
            Group {
                if library.designs.isEmpty {
                    emptyState
                } else {
                    gallery
                }
            }
            .navigationTitle("WidgetForge")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            showHelp = true
                        } label: {
                            Label("How it works", systemImage: "questionmark.circle")
                        }
                        Button {
                            showCredits = true
                        } label: {
                            Label("Credits", systemImage: "person.2")
                        }
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel("Help and credits")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showNew = true
                        } label: {
                            Label("New Widget", systemImage: "plus.square")
                        }
                        Button {
                            showGenerate = true
                        } label: {
                            Label("Generate with AI", systemImage: "sparkles")
                        }
                        Divider()
                        Button {
                            showImporter = true
                        } label: {
                            Label("Import Design File…", systemImage: "square.and.arrow.down")
                        }
                        Button {
                            showPasteCode = true
                        } label: {
                            Label("Paste Design Code…", systemImage: "doc.on.clipboard")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let design = library.design(id: id) {
                    EditorView(design: design, library: library)
                } else {
                    ContentUnavailableView("Widget not found", systemImage: "questionmark.square.dashed")
                }
            }
            .onAppear {
                library.reload()
            }
        }
        .sheet(isPresented: $showNew) {
            NewDesignView { design in
                library.path = [design.id]
            }
        }
        .sheet(isPresented: $showGenerate) {
            AIGenerateView { design in
                library.path = [design.id]
            }
        }
        .sheet(isPresented: $showPasteCode) {
            PasteCodeView()
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: importedTypes) { result in
            switch result {
            case .success(let url):
                library.importDesign(fromFileAt: url)
            case .failure(let error):
                library.importError = error.localizedDescription
            }
        }
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
        .sheet(isPresented: $showCredits) {
            CreditsSheet()
        }
        .sheet(item: $shareFile) { file in
            ActivityView(items: [file.url])
        }
        .alert("Copied", isPresented: $copiedCode) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The design's code is on your clipboard.")
        }
        .alert("Couldn't Import", isPresented: importErrorBinding, presenting: library.importError) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .alert("Couldn't Share", isPresented: shareErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(shareError ?? "")
        }
        .alert("Rename Widget", isPresented: renameBinding) {
            TextField("Name", text: $renameText)
            Button("Save") {
                if let design = renaming {
                    library.rename(design, to: renameText)
                }
                renaming = nil
            }
            Button("Cancel", role: .cancel) {
                renaming = nil
            }
        }
        .confirmationDialog(
            "Delete this widget?",
            isPresented: deleteBinding,
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { design in
            Button("Delete \"\(design.name)\"", role: .destructive) {
                library.delete(design)
                pendingDelete = nil
            }
        } message: { _ in
            Text("Any Home Screen widget showing it will go blank.")
        }
    }

    // MARK: Bindings

    private var renameBinding: Binding<Bool> {
        Binding(
            get: { renaming != nil },
            set: { isPresented in
                if !isPresented { renaming = nil }
            }
        )
    }

    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { isPresented in
                if !isPresented { pendingDelete = nil }
            }
        )
    }

    private var importErrorBinding: Binding<Bool> {
        Binding(
            get: { library.importError != nil },
            set: { isPresented in
                if !isPresented { library.importError = nil }
            }
        )
    }

    private var shareErrorBinding: Binding<Bool> {
        Binding(
            get: { shareError != nil },
            set: { isPresented in
                if !isPresented { shareError = nil }
            }
        )
    }

    private func shareDesign(_ design: WidgetDesign) {
        do {
            shareFile = ShareFile(url: try DesignExchange.exportFile(design))
        } catch {
            shareError = error.localizedDescription
        }
    }

    private func copyCode(_ design: WidgetDesign) {
        guard let text = try? DesignExchange.exportText(design) else {
            shareError = "Couldn't turn this design into text."
            return
        }
        UIPasteboard.general.string = text
        copiedCode = true
    }

    /// `.widgetforge` first (so Files shows a design someone shared as the expected type),
    /// falling back to plain JSON or text for a code someone saved by hand.
    private var importedTypes: [UTType] {
        var types: [UTType] = []
        if let custom = UTType(filenameExtension: DesignExchange.fileExtension) {
            types.append(custom)
        }
        types.append(contentsOf: [.json, .plainText])
        return types
    }

    // MARK: Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No widgets yet", systemImage: "square.grid.2x2")
        } description: {
            Text("Design your own Home Screen widget from scratch with text, clocks, countdowns, progress rings and photos.")
        } actions: {
            Button("Create a Widget") {
                showNew = true
            }
            .buttonStyle(.borderedProminent)
            Button("Generate with AI") {
                showGenerate = true
            }
            Button("Paste a Shared Design") {
                showPasteCode = true
            }
            Button("How it works") {
                showHelp = true
            }
        }
    }

    // MARK: Gallery

    private var gallery: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if !AppGroup.isAvailable {
                    setupWarning
                }
                ForEach(WidgetSize.allCases) { size in
                    section(for: size)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder private func section(for size: WidgetSize) -> some View {
        let items = library.designs.filter { $0.size == size }
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(size.title) widgets")
                    .font(.title3.weight(.semibold))
                LazyVGrid(columns: columns(for: size), alignment: .leading, spacing: 20) {
                    ForEach(items) { design in
                        card(design)
                    }
                }
            }
        }
    }

    private func columns(for size: WidgetSize) -> [GridItem] {
        switch size {
        case .small:
            return [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 16)]
        case .medium, .large:
            return [GridItem(.adaptive(minimum: 300, maximum: 420), spacing: 16)]
        }
    }

    private func card(_ design: WidgetDesign) -> some View {
        NavigationLink(value: design.id) {
            VStack(alignment: .leading, spacing: 8) {
                DesignThumbnail(design: design)
                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
                Text(design.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Text(design.elements.count == 1 ? "1 layer" : "\(design.elements.count) layers")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                library.path = [design.id]
            } label: {
                Label("Edit", systemImage: "slider.horizontal.3")
            }
            Button {
                library.duplicate(design)
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            Button {
                renameText = design.name
                renaming = design
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Divider()
            Button {
                shareDesign(design)
            } label: {
                Label("Share…", systemImage: "square.and.arrow.up")
            }
            Button {
                copyCode(design)
            } label: {
                Label("Copy Code", systemImage: "doc.on.doc")
            }
            Divider()
            Button(role: .destructive) {
                pendingDelete = design
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var setupWarning: some View {
        Button {
            showHelp = true
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Widgets can't see your designs yet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Text("The App Group isn't set up for this build. Tap for the fix.")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.orange.opacity(0.14)))
        }
        .buttonStyle(.plain)
    }
}
