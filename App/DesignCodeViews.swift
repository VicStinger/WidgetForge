import SwiftUI
import UIKit

// MARK: - View / edit a design's own code

/// Shows a design's underlying Design Code as editable text — the same JSON the app saves and
/// reads. Applying a change runs through the normal edit path (including Undo), so a bad edit
/// is never a dead end.
struct CodeEditorView: View {
    @ObservedObject var model: EditorModel
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var errorMessage: String?
    @State private var showCopied = false
    @State private var showReference = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let errorMessage {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.orange)
                        Text(errorMessage)
                            .font(.footnote)
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.14))
                }
                TextEditor(text: $text)
                    .font(.system(.footnote, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 4)
            }
            .navigationTitle("Design Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            UIPasteboard.general.string = text
                            showCopied = true
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        Button {
                            if let clip = UIPasteboard.general.string, !clip.isEmpty {
                                text = clip
                            }
                        } label: {
                            Label("Paste", systemImage: "doc.on.clipboard")
                        }
                        Button {
                            showReference = true
                        } label: {
                            Label("What's in this?", systemImage: "questionmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    Button("Apply") { apply() }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            text = (try? DesignExchange.exportText(model.design)) ?? ""
        }
        .alert("Copied", isPresented: $showCopied) {
            Button("OK", role: .cancel) {}
        }
        .sheet(isPresented: $showReference) {
            CodeReferenceView()
        }
    }

    private func apply() {
        do {
            try model.applyCode(text)
            errorMessage = nil
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Paste a code to import as a new design

/// Pastes someone else's shared Design Code (or an AI reply) in as a brand-new widget.
struct PasteCodeView: View {
    @EnvironmentObject private var library: DesignLibrary
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                if let errorMessage {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.orange)
                        Text(errorMessage)
                            .font(.footnote)
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.14))
                }
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .font(.system(.footnote, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 4)
                    if text.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Paste a Design Code here — from someone else's WidgetForge, a shared file's contents, or an AI reply.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button {
                                text = UIPasteboard.general.string ?? ""
                            } label: {
                                Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                        .allowsHitTesting(true)
                    }
                }
            }
            .padding(.top, 4)
            .navigationTitle("Paste Design Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { importCode() }
                        .fontWeight(.semibold)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func importCode() {
        switch library.importDesign(fromText: text) {
        case .success(let design):
            library.path = [design.id]
            dismiss()
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Schema reference

/// A short field guide to the JSON a design is made of — enough to hand-edit one or write one
/// from scratch.
struct CodeReferenceView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Top level") {
                    reference("size", "\"small\", \"medium\", or \"large\".")
                    reference("background", "kind (solid/linear/radial/image/glow), colors, angle.")
                    reference("elements", "An array of layers, drawn in order — later ones on top.")
                }
                Section("Every layer has") {
                    reference("kind", "text, date, countdown, progress, symbol, shape, image, device, or formula.")
                    reference("x, y", "Center position, 0 to 1 (0.5, 0.5 is the middle).")
                    reference("width, height", "Size, 0 to 1 of the canvas.")
                    reference("color", "{ \"r\":0-1, \"g\":0-1, \"b\":0-1, \"a\":0-1 }")
                }
                Section("Formula layers") {
                    reference("formulaSource", "Text with {...} spans, e.g. \"{battery}% battery\".")
                    reference("Values", "battery, charging, storageUsedPercent, storageFreeGB, uptimeHours, uptimeDays, online, day, weekday, month, year, dayProgress, weekProgress, monthProgress, yearProgress.")
                    reference("Functions", "round, floor, ceil, abs, min, max, percent(x), date(\"pattern\")")
                }
                Section {
                    Text("Share a design from its \"…\" menu or the Library's context menu — as a file, or as copyable text. Paste one back in from the Library's + menu.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Sharing")
                }
            }
            .navigationTitle("Design Code Reference")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func reference(_ key: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(key)
                .font(.subheadline.monospaced().weight(.semibold))
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
