import SwiftUI
import WidgetKit

/// The list of designs on disk plus navigation state for the library screen.
final class DesignLibrary: ObservableObject {
    @Published private(set) var designs: [WidgetDesign] = []
    /// Navigation stack: a design ID here means that design's editor is open.
    @Published var path: [UUID] = []
    /// Set when importing from a file or a shared link fails, for the library screen to show
    /// as an alert. Importing from the Paste Code sheet reports its own error inline instead.
    @Published var importError: String?

    init() {
        reload()
        removeUnusedImages()
    }

    func reload() {
        designs = DesignStorage.loadAll()
    }

    func design(id: UUID) -> WidgetDesign? {
        designs.first { $0.id == id } ?? DesignStorage.load(id: id)
    }

    // MARK: Creating and changing designs

    @discardableResult
    func create(size: WidgetSize, template: TemplateKind, name: String) -> WidgetDesign {
        var design = DesignTemplate.make(template, size: size)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            design.name = trimmed
        }
        persist(design)
        designs.insert(design, at: 0)
        return design
    }

    /// Writes a design to disk and refreshes widgets. Does not touch `designs`, so the editor
    /// can autosave without redrawing the library; the library reloads when it reappears.
    func persist(_ design: WidgetDesign) {
        var updated = design
        updated.modifiedAt = Date()
        DesignStorage.save(updated)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func rename(_ design: WidgetDesign, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = design
        updated.name = trimmed
        persist(updated)
        reload()
    }

    func duplicate(_ design: WidgetDesign) {
        var copy = design
        copy.id = UUID()
        copy.name = design.name + " Copy"
        copy.createdAt = Date()
        persist(copy)
        reload()
    }

    func delete(_ design: WidgetDesign) {
        DesignStorage.delete(id: design.id)
        designs.removeAll { $0.id == design.id }
        WidgetCenter.shared.reloadAllTimelines()
        removeUnusedImages()
    }

    // MARK: Import (Design Code — sharing, pasting, and AI generation all land here)

    /// Imports Design Code as a brand-new design in this library. Used by the Paste Code sheet
    /// and by AI generation, both of which show their own inline error on failure.
    @discardableResult
    func importDesign(fromText text: String) -> Result<WidgetDesign, Error> {
        do {
            let design = try DesignExchange.importPackage(from: text)
            persist(design)
            designs.insert(design, at: 0)
            return .success(design)
        } catch {
            return .failure(error)
        }
    }

    /// The same, from a file — used by the file importer and by opening a shared `.widgetforge`
    /// file. There's no dedicated screen already open to show an inline error in, so failures
    /// go to `importError` for the library screen's alert.
    func importDesign(fromFileAt url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            importError = "Couldn't read that file."
            return
        }
        switch importDesign(fromText: text) {
        case .success(let design):
            path = [design.id]
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    // MARK: Housekeeping

    /// Deletes photos no design uses. Skipped if any design file failed to load, so a
    /// decoding problem can never cost the user their pictures.
    private func removeUnusedImages() {
        let result = DesignStorage.loadAllReportingFailures()
        guard result.failedCount == 0 else { return }
        var used = Set<String>()
        for design in result.designs {
            used.formUnion(design.referencedImageIDs)
        }
        DesignStorage.removeUnusedImages(keeping: used)
    }

    // MARK: Deep links

    /// Handles `widgetforge://design/<uuid>` (tapping a widget opens its design) and opening a
    /// shared `.widgetforge` file (from AirDrop, Messages, Mail, or the Files app).
    func handle(url: URL) {
        if url.isFileURL {
            importDesign(fromFileAt: url)
            return
        }
        guard url.scheme == "widgetforge",
              url.host == "design",
              let id = UUID(uuidString: url.lastPathComponent) else { return }
        reload()
        if designs.contains(where: { $0.id == id }) {
            path = [id]
        }
    }
}
