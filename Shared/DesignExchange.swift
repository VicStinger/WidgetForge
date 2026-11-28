import Foundation
import UIKit

// MARK: - Design Code package

/// A design packaged for sharing: the design itself plus any photos it references, inlined as
/// base64 so the whole thing is one self-contained block of text — this is WidgetForge's
/// "Design Code". It's produced by exporting a design, by pasting a code someone else shared,
/// or by asking AI to write one; all three are read by `DesignExchange` below, so nothing
/// skips the same tolerant checks a design loaded from disk already gets.
struct DesignPackage {
    var app: String
    var formatVersion: Int
    var design: WidgetDesign
    var photos: [String: Data]?

    init(design: WidgetDesign, photos: [String: Data]? = nil) {
        self.app = "WidgetForge"
        self.formatVersion = 1
        self.design = design
        self.photos = photos
    }
}

extension DesignPackage: Codable {
    private enum CodingKeys: String, CodingKey { case app, formatVersion, design, photos }

    // Only "design" is required. A hand-written or AI-written code can leave out "app",
    // "formatVersion" and "photos" entirely and still import.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        app = (try? c.decode(String.self, forKey: .app)) ?? "WidgetForge"
        formatVersion = (try? c.decode(Int.self, forKey: .formatVersion)) ?? 1
        design = try c.decode(WidgetDesign.self, forKey: .design)
        photos = try? c.decodeIfPresent([String: Data].self, forKey: .photos)
    }
}

// MARK: - Exchange

/// Turns a design into portable "Design Code" text and back. Export, import, the in-app code
/// editor, and AI generation all go through this one place.
enum DesignExchange {
    struct ExchangeError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// The file extension used when sharing a design as a file (see the matching UTI
    /// declaration in WidgetForge-Info.plist).
    static let fileExtension = "widgetforge"

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: Export

    /// The design as portable Design Code: readable, pretty-printed JSON, with any photos it
    /// uses inlined so the text alone is everything someone else needs to recreate it.
    static func exportText(_ design: WidgetDesign) throws -> String {
        var photos: [String: Data] = [:]
        for id in design.referencedImageIDs {
            if let data = DesignStorage.imageData(id) {
                photos[id] = data
            }
        }
        let package = DesignPackage(design: design, photos: photos.isEmpty ? nil : photos)
        let data = try makeEncoder().encode(package)
        guard let text = String(data: data, encoding: .utf8) else {
            throw ExchangeError(message: "Couldn't turn this design into text.")
        }
        return text
    }

    /// Writes the design's Design Code to a temporary file for sharing (AirDrop, Messages,
    /// Files, Mail, ...). The caller doesn't need to clean it up — it's in the temp directory
    /// and named after the design, so re-sharing the same design reuses the same path.
    static func exportFile(_ design: WidgetDesign) throws -> URL {
        let text = try exportText(design)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let safeName = design.name.unicodeScalars.filter { allowed.contains($0) }
        let trimmedName = String(String.UnicodeScalarView(safeName)).trimmingCharacters(in: .whitespaces)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(trimmedName.isEmpty ? "Widget" : trimmedName)
            .appendingPathExtension(fileExtension)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: Decode (no side effects — used to edit a design's own code in place)

    /// Parses Design Code into a design, without assigning new photo IDs or a new design ID.
    /// Used by the in-app code editor, where the result replaces a design that's already in
    /// the library under its own identity.
    static func decodeDesign(from text: String) throws -> WidgetDesign {
        try decodeDesignAndPhotos(from: text).design
    }

    private static func decodeDesignAndPhotos(from text: String) throws -> (design: WidgetDesign, photos: [String: Data]) {
        var lastError: Error = ExchangeError(message: "That didn't look like a WidgetForge design.")
        for candidate in candidateTexts(from: text) {
            guard let data = candidate.data(using: .utf8) else { continue }
            let decoder = makeDecoder()
            do {
                let package = try decoder.decode(DesignPackage.self, from: data)
                return (package.design, package.photos ?? [:])
            } catch let packageError {
                if let design = try? decoder.decode(WidgetDesign.self, from: data) {
                    return (design, [:])
                }
                lastError = ExchangeError(message: friendlyMessage(for: packageError))
            }
        }
        throw lastError
    }

    // MARK: Import (for a design coming from outside this library)

    /// The same parsing, but for importing a design someone else shared: every referenced
    /// photo is re-homed under a fresh ID and the design gets a new ID and timestamps, so
    /// importing never collides with an existing design or photo already in this library.
    static func importPackage(from text: String) throws -> WidgetDesign {
        let (design, photos) = try decodeDesignAndPhotos(from: text)
        var imported = design
        imported.id = UUID()
        imported.createdAt = Date()
        imported.modifiedAt = Date()
        if imported.name.trimmingCharacters(in: .whitespaces).isEmpty {
            imported.name = "Imported Widget"
        }

        var remap: [String: String] = [:]
        func rehome(_ oldID: String?) -> String? {
            guard let oldID else { return nil }
            if let already = remap[oldID] { return already }
            guard let data = photos[oldID], let image = UIImage(data: data) else { return nil }
            let newID = DesignStorage.saveImage(image, maxDimension: 1400)
            remap[oldID] = newID
            return newID
        }
        imported.background.imageID = rehome(imported.background.imageID)
        for i in imported.elements.indices {
            imported.elements[i].imageID = rehome(imported.elements[i].imageID)
        }
        return imported
    }

    // MARK: Tolerant text handling

    /// The text as given, then — if that doesn't parse — with a ```fence``` stripped, then
    /// just the first balanced `{...}` object found anywhere in the text. Covers a plain
    /// export, a fenced code block, and an AI reply with a sentence before or after the JSON.
    private static func candidateTexts(from text: String) -> [String] {
        var ordered: [String] = []
        func add(_ candidate: String?) {
            guard let candidate else { return }
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !ordered.contains(trimmed) else { return }
            ordered.append(trimmed)
        }
        add(text)
        add(stripCodeFence(text))
        add(extractFirstJSONObject(text))
        return ordered
    }

    private static func stripCodeFence(_ text: String) -> String? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return nil }
        trimmed.removeFirst(3)
        if let newlineIndex = trimmed.firstIndex(of: "\n") {
            trimmed.removeSubrange(trimmed.startIndex...newlineIndex)
        }
        if let fenceRange = trimmed.range(of: "```", options: .backwards) {
            trimmed.removeSubrange(fenceRange.lowerBound..<trimmed.endIndex)
        }
        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The first balanced `{...}` block in `text`, ignoring braces inside quoted strings.
    private static func extractFirstJSONObject(_ text: String) -> String? {
        let chars = Array(text)
        guard let start = chars.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escaped = false
        var i = start
        while i < chars.count {
            let c = chars[i]
            if inString {
                if escaped {
                    escaped = false
                } else if c == "\\" {
                    escaped = true
                } else if c == "\"" {
                    inString = false
                }
            } else if c == "\"" {
                inString = true
            } else if c == "{" {
                depth += 1
            } else if c == "}" {
                depth -= 1
                if depth == 0 { return String(chars[start...i]) }
            }
            i += 1
        }
        return nil
    }

    private static func friendlyMessage(for error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return "Couldn't read this as a design (\(error.localizedDescription))."
        }
        switch decodingError {
        case .dataCorrupted(let context):
            return "This isn't valid JSON: \(context.debugDescription)"
        case .keyNotFound(let key, let context):
            let path = (context.codingPath + [key]).map(\.stringValue).joined(separator: ".")
            return "Missing \"\(path)\"."
        case .typeMismatch(_, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Wrong kind of value at \"\(path)\": \(context.debugDescription)"
        case .valueNotFound(_, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Missing a value at \"\(path)\"."
        @unknown default:
            return "Couldn't read this as a design."
        }
    }
}
