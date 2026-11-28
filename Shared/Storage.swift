import Foundation
import UIKit

// MARK: - App Group

/// The App Group is how the app and the widget extension share designs and photos.
enum AppGroup {
    /// The group this build is configured for: Info.plist `AppGroupIdentifier`, falling back to
    /// `group.<app bundle id>`.
    private static var configuredIdentifier: String {
        if let value = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
           !value.isEmpty, !value.contains("$(") {
            return value
        }
        var bundleID = Bundle.main.bundleIdentifier ?? "com.example.WidgetForge"
        let suffix = ".Widget"
        if bundleID.hasSuffix(suffix) {
            bundleID.removeLast(suffix.count)
        }
        return "group." + bundleID
    }

    /// App Groups listed in the provisioning profile embedded in this bundle, which are the groups
    /// iOS really granted. Sideloading tools (AltStore, Sideloadly, ...) re-sign the app with your
    /// own Apple ID and may rename the group, so this is the most reliable source. App Store and
    /// Simulator builds have no embedded profile and give an empty list.
    private static func provisionedGroups() -> [String] {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .isoLatin1),
              let start = text.range(of: "<?xml"),
              let end = text.range(of: "</plist>", range: start.lowerBound..<text.endIndex),
              let xml = String(text[start.lowerBound..<end.upperBound]).data(using: .isoLatin1),
              let plist = try? PropertyListSerialization.propertyList(from: xml, options: [], format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let groups = entitlements["com.apple.security.application-groups"] as? [String]
        else { return [] }
        return groups
    }

    private struct Resolution {
        let identifier: String
        let containerURL: URL?
    }

    /// Looked up once per process: the first candidate that iOS gives a shared container for.
    private static let resolution: Resolution = {
        // AltStore writes the groups it registered into Info.plist under this key.
        let altStoreGroups = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] ?? []
        var seen = Set<String>()
        let candidates = (provisionedGroups() + altStoreGroups + [configuredIdentifier]).filter { id in
            !id.isEmpty && seen.insert(id).inserted
        }
        for id in candidates {
            if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
                return Resolution(identifier: id, containerURL: url)
            }
        }
        return Resolution(identifier: configuredIdentifier, containerURL: nil)
    }()

    /// The group in use, or the configured one when none of them is available.
    static var identifier: String { resolution.identifier }

    static var containerURL: URL? { resolution.containerURL }

    /// False when the entitlement is missing; the app still works but widgets can't see designs.
    static var isAvailable: Bool { containerURL != nil }
}

// MARK: - Design storage

/// File-based persistence: one JSON file per design plus a folder of downsized photos.
/// All members are static and safe to call from the widget extension.
enum DesignStorage {
    private static let imageCache = NSCache<NSString, UIImage>()

    // MARK: Locations

    /// Shared with `DeviceStats`, which caches the battery reading in the same container.
    static var rootURL: URL {
        let fm = FileManager.default
        let base: URL
        if let container = AppGroup.containerURL {
            base = container
        } else {
            base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        }
        let root = base.appendingPathComponent("WidgetForge", isDirectory: true)
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private static var designsURL: URL {
        let url = rootURL.appendingPathComponent("Designs", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static var imagesURL: URL {
        let url = rootURL.appendingPathComponent("Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func fileURL(for id: UUID) -> URL {
        designsURL.appendingPathComponent("\(id.uuidString).json")
    }

    // MARK: Coding

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: Designs

    /// Loads every readable design, newest first. `failedCount` is the number of files skipped.
    static func loadAll() -> [WidgetDesign] {
        loadAllReportingFailures().designs
    }

    static func loadAllReportingFailures() -> (designs: [WidgetDesign], failedCount: Int) {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: designsURL, includingPropertiesForKeys: nil)) ?? []
        let decoder = makeDecoder()
        var designs: [WidgetDesign] = []
        var failed = 0
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let design = try? decoder.decode(WidgetDesign.self, from: data) {
                designs.append(design)
            } else {
                failed += 1
            }
        }
        designs.sort { $0.modifiedAt > $1.modifiedAt }
        return (designs, failed)
    }

    static func load(id: UUID) -> WidgetDesign? {
        guard let data = try? Data(contentsOf: fileURL(for: id)) else { return nil }
        return try? makeDecoder().decode(WidgetDesign.self, from: data)
    }

    static func save(_ design: WidgetDesign) {
        guard let data = try? makeEncoder().encode(design) else { return }
        try? data.write(to: fileURL(for: design.id), options: .atomic)
    }

    static func delete(id: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: id))
    }

    // MARK: Images

    private static func imageURL(_ id: String) -> URL {
        imagesURL.appendingPathComponent(id)
    }

    /// Downsizes and stores a photo as JPEG. Returns the file ID to reference from a design.
    static func saveImage(_ image: UIImage, maxDimension: CGFloat) -> String? {
        let resized = downscaled(image, maxDimension: maxDimension)
        guard let data = resized.jpegData(compressionQuality: 0.85) else { return nil }
        let id = UUID().uuidString + ".jpg"
        do {
            try data.write(to: imageURL(id), options: .atomic)
            return id
        } catch {
            return nil
        }
    }

    static func loadImage(_ id: String) -> UIImage? {
        let key = id as NSString
        if let cached = imageCache.object(forKey: key) { return cached }
        guard let image = UIImage(contentsOfFile: imageURL(id).path) else { return nil }
        imageCache.setObject(image, forKey: key)
        return image
    }

    /// Raw JPEG bytes for a stored photo, for packaging a design into a portable export file.
    static func imageData(_ id: String) -> Data? {
        try? Data(contentsOf: imageURL(id))
    }

    /// Removes photos no design references any more.
    static func removeUnusedImages(keeping used: Set<String>) {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: imagesURL, includingPropertiesForKeys: nil)) ?? []
        for file in files where !used.contains(file.lastPathComponent) {
            try? fm.removeItem(at: file)
            imageCache.removeObject(forKey: file.lastPathComponent as NSString)
        }
    }

    private static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return image }
        let factor = maxDimension / longest
        let newSize = CGSize(width: size.width * factor, height: size.height * factor)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
