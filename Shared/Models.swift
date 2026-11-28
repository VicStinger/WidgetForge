import SwiftUI
import UIKit

// MARK: - Tolerant decoding

private extension KeyedDecodingContainer {
    /// Decodes a value, using `fallback` when the key is missing or unreadable. Saved designs
    /// therefore keep loading after a new property is added in a later version of the app.
    func value<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }

    /// The same, for optional properties.
    func optionalValue<T: Decodable>(_ key: Key) -> T? {
        try? decodeIfPresent(T.self, forKey: key)
    }
}

// MARK: - Widget sizes

/// The three Home Screen widget sizes a design can target.
enum WidgetSize: String, Codable, CaseIterable, Identifiable {
    case small, medium, large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    var iconName: String {
        switch self {
        case .small: return "square"
        case .medium: return "rectangle"
        case .large: return "square.split.1x2"
        }
    }

    /// Reference canvas in points (a 6.1" iPhone). Font sizes, corner radii and
    /// line widths are stored against this size and scaled at render time.
    var referenceSize: CGSize {
        switch self {
        case .small: return CGSize(width: 158, height: 158)
        case .medium: return CGSize(width: 338, height: 158)
        case .large: return CGSize(width: 338, height: 354)
        }
    }

    var aspectRatio: CGFloat { referenceSize.width / referenceSize.height }
}

// MARK: - Color

/// A Codable sRGB color.
struct RGBAColor: Codable, Equatable, Hashable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    init(hex: UInt32, alpha: Double = 1) {
        self.r = Double((hex >> 16) & 0xFF) / 255.0
        self.g = Double((hex >> 8) & 0xFF) / 255.0
        self.b = Double(hex & 0xFF) / 255.0
        self.a = alpha
    }

    init(_ color: Color) {
        let ui = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        ui.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(
            r: min(max(Double(red), 0), 1),
            g: min(max(Double(green), 0), 1),
            b: min(max(Double(blue), 0), 1),
            a: min(max(Double(alpha), 0), 1)
        )
    }

    var color: Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    func withAlpha(_ alpha: Double) -> RGBAColor {
        RGBAColor(r: r, g: g, b: b, a: alpha)
    }

    static let white = RGBAColor(hex: 0xFFFFFF)
    static let black = RGBAColor(hex: 0x000000)
    static let ink = RGBAColor(hex: 0x111318)
}

// MARK: - Text styling options

enum FontWeightOption: String, Codable, CaseIterable, Identifiable {
    case light, regular, medium, semibold, bold, heavy, black

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var weight: Font.Weight {
        switch self {
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }
}

enum FontDesignOption: String, Codable, CaseIterable, Identifiable {
    case standard, rounded, serif, monospaced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "Default"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        case .monospaced: return "Mono"
        }
    }

    var design: Font.Design {
        switch self {
        case .standard: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        case .monospaced: return .monospaced
        }
    }
}

enum TextAlignOption: String, Codable, CaseIterable, Identifiable {
    case leading, center, trailing

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .leading: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .trailing: return "text.alignright"
        }
    }

    var textAlignment: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

// MARK: - Element kinds and options

enum ElementKind: String, Codable, CaseIterable, Identifiable {
    case text, date, countdown, progress, symbol, shape, image, device, formula

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: return "Text"
        case .date: return "Time & Date"
        case .countdown: return "Countdown"
        case .progress: return "Progress"
        case .symbol: return "Symbol"
        case .shape: return "Shape"
        case .image: return "Photo"
        case .device: return "Device"
        case .formula: return "Formula"
        }
    }

    var iconName: String {
        switch self {
        case .text: return "textformat"
        case .date: return "clock"
        case .countdown: return "hourglass"
        case .progress: return "circle.dashed"
        case .symbol: return "star"
        case .shape: return "square.on.circle"
        case .image: return "photo"
        case .device: return "iphone"
        case .formula: return "chevron.left.forwardslash.chevron.right"
        }
    }

    /// True for elements that render a string with font styling.
    var isTextual: Bool {
        self == .text || self == .date || self == .countdown || self == .device || self == .formula
    }
}

enum DateFormatOption: String, Codable, CaseIterable, Identifiable {
    case time, timeCompact, weekday, weekdayShort, day, monthDay, fullDate, month, year, custom
    case dayYesterday, dayTomorrow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .time: return "Time"
        case .timeCompact: return "Time (no AM/PM)"
        case .weekday: return "Weekday"
        case .weekdayShort: return "Weekday (short)"
        case .day: return "Day number"
        case .monthDay: return "Month & day"
        case .fullDate: return "Full date"
        case .month: return "Month"
        case .year: return "Year"
        case .custom: return "Custom pattern"
        case .dayYesterday: return "Day number (yesterday)"
        case .dayTomorrow: return "Day number (tomorrow)"
        }
    }
}

enum ShapeKind: String, Codable, CaseIterable, Identifiable {
    case rectangle, rounded, ellipse, capsule

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rectangle: return "Rectangle"
        case .rounded: return "Rounded"
        case .ellipse: return "Ellipse"
        case .capsule: return "Capsule"
        }
    }

    var iconName: String {
        switch self {
        case .rectangle: return "rectangle"
        case .rounded: return "app"
        case .ellipse: return "circle"
        case .capsule: return "capsule"
        }
    }
}

enum ProgressSource: String, Codable, CaseIterable, Identifiable {
    case manual, day, week, month, year, storage, battery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual: return "Manual value"
        case .day: return "Progress of today"
        case .week: return "Progress of this week"
        case .month: return "Progress of this month"
        case .year: return "Progress of this year"
        case .storage: return "Storage used"
        case .battery: return "Battery level"
        }
    }
}

enum ProgressKind: String, Codable, CaseIterable, Identifiable {
    case ring, bar, dial

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ImageFit: String, Codable, CaseIterable, Identifiable {
    case fill, fit

    var id: String { rawValue }
    var title: String { self == .fill ? "Fill" : "Fit" }
}

/// A fact about this device (not any other app) that a Device layer can show.
enum DeviceStatKind: String, Codable, CaseIterable, Identifiable {
    case battery, storage, uptime, network, deviceInfo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .battery: return "Battery"
        case .storage: return "Free Storage"
        case .uptime: return "Uptime"
        case .network: return "Connection"
        case .deviceInfo: return "Device Name"
        }
    }
}

// MARK: - Element

/// One layer on the widget canvas. Geometry is stored normalised (0...1) against the
/// canvas so a design scales across devices; the position is the element's centre.
struct DesignElement: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var kind: ElementKind
    var name: String

    // Geometry (normalised)
    var x: Double = 0.5
    var y: Double = 0.5
    var width: Double = 0.5
    var height: Double = 0.25
    var rotation: Double = 0
    var opacity: Double = 1
    var isHidden: Bool = false
    var isLocked: Bool = false

    // Colours
    var color: RGBAColor = .white
    var secondaryColor: RGBAColor = RGBAColor(hex: 0xFFFFFF, alpha: 0.25)

    // Text-like
    var text: String = ""
    var fontSize: Double = 24
    var weight: FontWeightOption = .semibold
    var fontDesign: FontDesignOption = .standard
    var alignment: TextAlignOption = .center
    var isUppercase: Bool = false

    // Date & countdown
    var dateFormat: DateFormatOption = .time
    var customFormat: String = "EEEE, MMM d"
    var targetDate: Date = Date().addingTimeInterval(60 * 60 * 24 * 30)

    // Symbol
    var symbolName: String = "star.fill"

    // Shape
    var shape: ShapeKind = .rounded
    var cornerRadius: Double = 16
    var isFilled: Bool = true
    var lineWidth: Double = 4
    var isGlass: Bool = false

    // Progress
    var progressSource: ProgressSource = .day
    var progressValue: Double = 0.6
    var progressKind: ProgressKind = .ring
    var showsLabel: Bool = true

    // Image
    var imageID: String? = nil
    var imageFit: ImageFit = .fill

    // Device
    var deviceStat: DeviceStatKind = .battery

    // Formula ("coding" layer): a small, sandboxed template language. See FormulaEngine.
    var formulaSource: String = "{battery}% battery"

    init(kind: ElementKind, name: String) {
        self.kind = kind
        self.name = name
    }

    // Every property is decoded with a fallback, so adding a property later never makes
    // previously saved designs unreadable. Add new properties to both places below.
    private enum CodingKeys: String, CodingKey {
        case id, kind, name
        case x, y, width, height, rotation, opacity, isHidden, isLocked
        case color, secondaryColor
        case text, fontSize, weight, fontDesign, alignment, isUppercase
        case dateFormat, customFormat, targetDate
        case symbolName
        case shape, cornerRadius, isFilled, lineWidth
        case progressSource, progressValue, progressKind, showsLabel
        case imageID, imageFit
        case deviceStat
        case isGlass
        case formulaSource
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(kind: c.value(.kind, ElementKind.text), name: c.value(.name, "Layer"))
        id = c.value(.id, id)
        x = c.value(.x, x)
        y = c.value(.y, y)
        width = c.value(.width, width)
        height = c.value(.height, height)
        rotation = c.value(.rotation, rotation)
        opacity = c.value(.opacity, opacity)
        isHidden = c.value(.isHidden, isHidden)
        isLocked = c.value(.isLocked, isLocked)
        color = c.value(.color, color)
        secondaryColor = c.value(.secondaryColor, secondaryColor)
        text = c.value(.text, text)
        fontSize = c.value(.fontSize, fontSize)
        weight = c.value(.weight, weight)
        fontDesign = c.value(.fontDesign, fontDesign)
        alignment = c.value(.alignment, alignment)
        isUppercase = c.value(.isUppercase, isUppercase)
        dateFormat = c.value(.dateFormat, dateFormat)
        customFormat = c.value(.customFormat, customFormat)
        targetDate = c.value(.targetDate, targetDate)
        symbolName = c.value(.symbolName, symbolName)
        shape = c.value(.shape, shape)
        cornerRadius = c.value(.cornerRadius, cornerRadius)
        isFilled = c.value(.isFilled, isFilled)
        lineWidth = c.value(.lineWidth, lineWidth)
        progressSource = c.value(.progressSource, progressSource)
        progressValue = c.value(.progressValue, progressValue)
        progressKind = c.value(.progressKind, progressKind)
        showsLabel = c.value(.showsLabel, showsLabel)
        imageID = c.optionalValue(.imageID)
        imageFit = c.value(.imageFit, imageFit)
        deviceStat = c.value(.deviceStat, deviceStat)
        isGlass = c.value(.isGlass, isGlass)
        formulaSource = c.value(.formulaSource, formulaSource)
    }

    /// Whether this element needs its content refreshed every minute.
    var needsMinuteUpdates: Bool {
        kind == .date && (dateFormat == .time || dateFormat == .timeCompact || dateFormat == .custom)
    }

    /// Sets the box size from point dimensions on the given widget's reference canvas.
    mutating func setBox(width points: Double, height heightPoints: Double, in size: WidgetSize) {
        let ref = size.referenceSize
        width = points / Double(ref.width)
        height = heightPoints / Double(ref.height)
    }

    /// A new element of the given kind with sensible defaults for the widget size.
    static func make(_ kind: ElementKind, in size: WidgetSize) -> DesignElement {
        var e = DesignElement(kind: kind, name: kind.title)
        switch kind {
        case .text:
            e.text = "Hello"
            e.fontSize = 28
            e.setBox(width: 120, height: 44, in: size)
        case .date:
            e.dateFormat = .time
            e.fontSize = 40
            e.weight = .bold
            e.fontDesign = .rounded
            e.setBox(width: 140, height: 56, in: size)
        case .countdown:
            e.text = "{n} days"
            e.fontSize = 28
            e.weight = .bold
            e.fontDesign = .rounded
            e.setBox(width: 130, height: 44, in: size)
        case .progress:
            e.progressSource = .year
            e.progressKind = .ring
            e.lineWidth = 10
            e.color = RGBAColor(hex: 0x7CF2C5)
            e.fontDesign = .rounded
            e.setBox(width: 90, height: 90, in: size)
        case .symbol:
            e.symbolName = "star.fill"
            e.color = RGBAColor(hex: 0xFFD166)
            e.setBox(width: 56, height: 56, in: size)
        case .shape:
            e.shape = .rounded
            e.cornerRadius = 18
            e.color = RGBAColor(hex: 0xFFFFFF, alpha: 0.2)
            e.setBox(width: 110, height: 70, in: size)
        case .image:
            e.cornerRadius = 16
            e.setBox(width: 110, height: 110, in: size)
        case .device:
            e.deviceStat = .battery
            e.fontSize = 20
            e.weight = .semibold
            e.fontDesign = .rounded
            e.setBox(width: 150, height: 40, in: size)
        case .formula:
            e.formulaSource = "{battery}% battery"
            e.fontSize = 24
            e.weight = .semibold
            e.fontDesign = .rounded
            e.setBox(width: 150, height: 40, in: size)
        }
        return e
    }
}

// MARK: - Background

enum BackgroundKind: String, Codable, CaseIterable, Identifiable {
    case solid, linear, radial, image, glow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .solid: return "Solid"
        case .linear: return "Linear"
        case .radial: return "Radial"
        case .image: return "Photo"
        case .glow: return "Glow"
        }
    }
}

struct DesignBackground: Codable, Equatable {
    var kind: BackgroundKind = .linear
    /// Up to three colours. `solid` uses the first.
    var colors: [RGBAColor] = [RGBAColor(hex: 0x1D2671), RGBAColor(hex: 0xC33764)]
    /// Gradient direction in degrees: 0 = bottom→top, 90 = left→right, 180 = top→bottom.
    var angle: Double = 135
    var imageID: String? = nil
    /// Black overlay strength on top of a photo, 0...1.
    var imageDim: Double = 0.25

    init(
        kind: BackgroundKind = .linear,
        colors: [RGBAColor] = [RGBAColor(hex: 0x1D2671), RGBAColor(hex: 0xC33764)],
        angle: Double = 135,
        imageID: String? = nil,
        imageDim: Double = 0.25
    ) {
        self.kind = kind
        self.colors = colors
        self.angle = angle
        self.imageID = imageID
        self.imageDim = imageDim
    }

    private enum CodingKeys: String, CodingKey {
        case kind, colors, angle, imageID, imageDim
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            kind: c.value(.kind, BackgroundKind.linear),
            colors: c.value(.colors, [RGBAColor(hex: 0x1D2671), RGBAColor(hex: 0xC33764)]),
            angle: c.value(.angle, 135.0),
            imageID: c.optionalValue(.imageID),
            imageDim: c.value(.imageDim, 0.25)
        )
    }

    static let midnight = DesignBackground()

    static func gradient(_ a: UInt32, _ b: UInt32, angle: Double = 135) -> DesignBackground {
        DesignBackground(kind: .linear, colors: [RGBAColor(hex: a), RGBAColor(hex: b)], angle: angle)
    }

    static func solid(_ hex: UInt32) -> DesignBackground {
        DesignBackground(kind: .solid, colors: [RGBAColor(hex: hex)])
    }
}

// MARK: - Design

struct WidgetDesign: Identifiable, Codable, Equatable {
    var schemaVersion: Int = 1
    var id: UUID = UUID()
    var name: String
    var size: WidgetSize
    var background: DesignBackground = .midnight
    var elements: [DesignElement] = []
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    init(
        name: String,
        size: WidgetSize,
        background: DesignBackground = .midnight,
        elements: [DesignElement] = []
    ) {
        self.name = name
        self.size = size
        self.background = background
        self.elements = elements
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, name, size, background, elements, createdAt, modifiedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(name: c.value(.name, "Widget"), size: c.value(.size, WidgetSize.small))
        schemaVersion = c.value(.schemaVersion, 1)
        id = c.value(.id, id)
        background = c.value(.background, background)
        elements = c.value(.elements, elements)
        createdAt = c.value(.createdAt, createdAt)
        modifiedAt = c.value(.modifiedAt, modifiedAt)
    }

    /// Image file IDs referenced by this design (background and photo elements).
    var referencedImageIDs: Set<String> {
        var ids = Set<String>()
        if let id = background.imageID { ids.insert(id) }
        for element in elements {
            if let id = element.imageID { ids.insert(id) }
        }
        return ids
    }
}
