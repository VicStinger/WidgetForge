import Foundation

/// Starting points offered when creating a new design.
enum TemplateKind: String, CaseIterable, Identifiable {
    case blank, clock, countdown, progress, quote, photo, device, glow, gauge, glass, bigDate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blank: return "Blank"
        case .clock: return "Clock"
        case .countdown: return "Countdown"
        case .progress: return "Year Progress"
        case .quote: return "Quote"
        case .photo: return "Photo"
        case .device: return "Device Stats"
        case .glow: return "Glow Clock"
        case .gauge: return "Battery Gauge"
        case .glass: return "Glass Card"
        case .bigDate: return "Big Numerals"
        }
    }

    var subtitle: String {
        switch self {
        case .blank: return "Start from scratch"
        case .clock: return "Live time and date"
        case .countdown: return "Days until an event"
        case .progress: return "How far through the year"
        case .quote: return "Words you like"
        case .photo: return "Your picture, your caption"
        case .device: return "Battery, storage, network"
        case .glow: return "A glowing, Widgy-style background"
        case .gauge: return "A dial gauge for battery"
        case .glass: return "A frosted glass panel"
        case .bigDate: return "Oversized day number"
        }
    }
}

enum DesignTemplate {
    static func make(_ kind: TemplateKind, size: WidgetSize) -> WidgetDesign {
        switch kind {
        case .blank: return blank(size)
        case .clock: return clock(size)
        case .countdown: return countdown(size)
        case .progress: return progress(size)
        case .quote: return quote(size)
        case .photo: return photo(size)
        case .device: return device(size)
        case .glow: return glow(size)
        case .gauge: return gauge(size)
        case .glass: return glass(size)
        case .bigDate: return bigDate(size)
        }
    }

    // MARK: Element helpers

    private static func label(
        _ string: String,
        name: String,
        x: Double, y: Double, w: Double, h: Double,
        font: Double,
        weight: FontWeightOption = .semibold,
        design: FontDesignOption = .standard,
        color: RGBAColor = .white,
        align: TextAlignOption = .center,
        uppercase: Bool = false
    ) -> DesignElement {
        var e = DesignElement(kind: .text, name: name)
        e.text = string
        e.x = x
        e.y = y
        e.width = w
        e.height = h
        e.fontSize = font
        e.weight = weight
        e.fontDesign = design
        e.color = color
        e.alignment = align
        e.isUppercase = uppercase
        return e
    }

    private static func clockText(
        _ format: DateFormatOption,
        name: String,
        x: Double, y: Double, w: Double, h: Double,
        font: Double,
        weight: FontWeightOption = .semibold,
        design: FontDesignOption = .standard,
        color: RGBAColor = .white,
        align: TextAlignOption = .center
    ) -> DesignElement {
        var e = label("", name: name, x: x, y: y, w: w, h: h, font: font, weight: weight, design: design, color: color, align: align)
        e.kind = .date
        e.dateFormat = format
        return e
    }

    private static func blank(_ size: WidgetSize) -> WidgetDesign {
        WidgetDesign(name: "Untitled", size: size, background: .gradient(0x1D2671, 0xC33764), elements: [])
    }

    // MARK: Clock

    private static func clock(_ size: WidgetSize) -> WidgetDesign {
        let dim = RGBAColor.white.withAlpha(0.85)
        let faint = RGBAColor.white.withAlpha(0.6)
        var elements: [DesignElement]
        switch size {
        case .small:
            elements = [
                clockText(.time, name: "Time", x: 0.5, y: 0.40, w: 0.92, h: 0.30, font: 40, weight: .bold, design: .rounded),
                clockText(.weekday, name: "Weekday", x: 0.5, y: 0.66, w: 0.9, h: 0.14, font: 17, color: dim),
                clockText(.monthDay, name: "Date", x: 0.5, y: 0.80, w: 0.9, h: 0.12, font: 14, weight: .medium, color: faint)
            ]
        case .medium:
            elements = [
                clockText(.time, name: "Time", x: 0.5, y: 0.38, w: 0.9, h: 0.46, font: 62, weight: .bold, design: .rounded),
                clockText(.weekday, name: "Weekday", x: 0.5, y: 0.70, w: 0.9, h: 0.16, font: 20, color: dim),
                clockText(.monthDay, name: "Date", x: 0.5, y: 0.85, w: 0.9, h: 0.12, font: 15, weight: .medium, color: faint)
            ]
        case .large:
            var bar = DesignElement.make(.progress, in: size)
            bar.name = "Day progress"
            bar.progressSource = .day
            bar.progressKind = .bar
            bar.x = 0.5
            bar.y = 0.82
            bar.width = 0.8
            bar.height = 0.06
            bar.lineWidth = 10
            bar.color = RGBAColor(hex: 0x7CC6FE)
            elements = [
                clockText(.time, name: "Time", x: 0.5, y: 0.30, w: 0.92, h: 0.26, font: 72, weight: .bold, design: .rounded),
                clockText(.weekday, name: "Weekday", x: 0.5, y: 0.52, w: 0.9, h: 0.10, font: 24, color: dim),
                clockText(.monthDay, name: "Date", x: 0.5, y: 0.61, w: 0.9, h: 0.08, font: 17, weight: .medium, color: faint),
                label("Today", name: "Caption", x: 0.5, y: 0.74, w: 0.8, h: 0.06, font: 13, color: faint, uppercase: true),
                bar
            ]
        }
        return WidgetDesign(name: "Clock", size: size, background: .gradient(0x141E30, 0x35577D, angle: 160), elements: elements)
    }

    // MARK: Countdown

    private static func countdown(_ size: WidgetSize) -> WidgetDesign {
        let faint = RGBAColor.white.withAlpha(0.8)
        var number = DesignElement.make(.countdown, in: size)
        number.name = "Days"
        number.text = "{n}"
        number.weight = .heavy
        number.fontDesign = .rounded

        var icon = DesignElement.make(.symbol, in: size)
        icon.symbolName = "airplane"
        icon.color = .white

        var elements: [DesignElement] = []
        switch size {
        case .small:
            icon.x = 0.5
            icon.y = 0.2
            icon.setBox(width: 30, height: 30, in: size)
            number.x = 0.5
            number.y = 0.5
            number.width = 0.9
            number.height = 0.34
            number.fontSize = 56
            elements = [
                icon,
                number,
                label("days until", name: "Caption", x: 0.5, y: 0.73, w: 0.9, h: 0.1, font: 14, color: faint),
                label("Vacation", name: "Title", x: 0.5, y: 0.86, w: 0.9, h: 0.12, font: 17, weight: .bold)
            ]
        case .medium:
            icon.x = 0.66
            icon.y = 0.24
            icon.setBox(width: 30, height: 30, in: size)
            number.x = 0.27
            number.y = 0.5
            number.width = 0.46
            number.height = 0.7
            number.fontSize = 88
            elements = [
                number,
                icon,
                label("days until", name: "Caption", x: 0.74, y: 0.42, w: 0.4, h: 0.14, font: 16, color: faint, align: .leading),
                label("Vacation", name: "Title", x: 0.74, y: 0.62, w: 0.4, h: 0.2, font: 26, weight: .bold, align: .leading)
            ]
        case .large:
            icon.x = 0.5
            icon.y = 0.18
            icon.setBox(width: 54, height: 54, in: size)
            number.x = 0.5
            number.y = 0.5
            number.width = 0.9
            number.height = 0.4
            number.fontSize = 130
            elements = [
                icon,
                number,
                label("days until", name: "Caption", x: 0.5, y: 0.74, w: 0.9, h: 0.07, font: 20, color: faint),
                label("Vacation", name: "Title", x: 0.5, y: 0.85, w: 0.9, h: 0.1, font: 32, weight: .bold)
            ]
        }
        return WidgetDesign(name: "Countdown", size: size, background: .gradient(0xFF512F, 0xDD2476, angle: 150), elements: elements)
    }

    // MARK: Year progress

    private static func progress(_ size: WidgetSize) -> WidgetDesign {
        let faint = RGBAColor.white.withAlpha(0.75)
        var ring = DesignElement.make(.progress, in: size)
        ring.name = "Year ring"
        ring.progressSource = .year
        ring.progressKind = .ring
        ring.color = RGBAColor(hex: 0xE9FFF2)
        ring.secondaryColor = RGBAColor.white.withAlpha(0.22)
        ring.weight = .bold

        var elements: [DesignElement] = []
        switch size {
        case .small:
            ring.x = 0.5
            ring.y = 0.44
            ring.setBox(width: 100, height: 100, in: size)
            ring.lineWidth = 12
            elements = [
                ring,
                label("Year progress", name: "Caption", x: 0.5, y: 0.86, w: 0.9, h: 0.12, font: 13, color: faint)
            ]
        case .medium:
            ring.x = 0.24
            ring.y = 0.5
            ring.setBox(width: 112, height: 112, in: size)
            ring.lineWidth = 13
            var year = DesignElement.make(.date, in: size)
            year.name = "Year"
            year.dateFormat = .year
            year.x = 0.66
            year.y = 0.56
            year.width = 0.5
            year.height = 0.4
            year.fontSize = 52
            year.alignment = .leading
            elements = [
                ring,
                label("Year progress", name: "Caption", x: 0.66, y: 0.30, w: 0.5, h: 0.14, font: 15, color: faint, align: .leading),
                year
            ]
        case .large:
            ring.x = 0.5
            ring.y = 0.45
            ring.setBox(width: 220, height: 220, in: size)
            ring.lineWidth = 22
            var year = DesignElement.make(.date, in: size)
            year.name = "Year"
            year.dateFormat = .year
            year.x = 0.5
            year.y = 0.86
            year.width = 0.8
            year.height = 0.1
            year.fontSize = 34
            elements = [ring, year]
        }
        return WidgetDesign(name: "Year Progress", size: size, background: .gradient(0x134E5E, 0x71B280, angle: 160), elements: elements)
    }

    // MARK: Quote

    private static func quote(_ size: WidgetSize) -> WidgetDesign {
        let ink = RGBAColor(hex: 0x2B2D42)
        let accent = RGBAColor(hex: 0xE76F51)
        var bar = DesignElement.make(.shape, in: size)
        bar.name = "Accent"
        bar.shape = .capsule
        bar.color = accent

        var elements: [DesignElement] = []
        switch size {
        case .small:
            bar.x = 0.5
            bar.y = 0.1
            bar.setBox(width: 34, height: 5, in: size)
            elements = [
                bar,
                label("Make something people want.", name: "Quote", x: 0.5, y: 0.47, w: 0.84, h: 0.52, font: 17, weight: .semibold, design: .serif, color: ink, align: .leading),
                label("Paul Graham", name: "Author", x: 0.5, y: 0.86, w: 0.84, h: 0.1, font: 11, weight: .medium, color: accent, align: .leading, uppercase: true)
            ]
        case .medium:
            bar.x = 0.07
            bar.y = 0.5
            bar.setBox(width: 5, height: 100, in: size)
            elements = [
                bar,
                label("Make something people want.", name: "Quote", x: 0.55, y: 0.44, w: 0.82, h: 0.56, font: 24, weight: .semibold, design: .serif, color: ink, align: .leading),
                label("Paul Graham", name: "Author", x: 0.55, y: 0.82, w: 0.82, h: 0.12, font: 12, weight: .medium, color: accent, align: .leading, uppercase: true)
            ]
        case .large:
            bar.x = 0.5
            bar.y = 0.12
            bar.setBox(width: 54, height: 7, in: size)
            elements = [
                bar,
                label("Make something people want.", name: "Quote", x: 0.5, y: 0.47, w: 0.82, h: 0.5, font: 34, weight: .semibold, design: .serif, color: ink, align: .leading),
                label("Paul Graham", name: "Author", x: 0.5, y: 0.86, w: 0.82, h: 0.07, font: 14, weight: .medium, color: accent, align: .leading, uppercase: true)
            ]
        }
        return WidgetDesign(name: "Quote", size: size, background: .solid(0xF6EFE0), elements: elements)
    }

    // MARK: Photo

    private static func photo(_ size: WidgetSize) -> WidgetDesign {
        var background = DesignBackground()
        background.kind = .image
        background.imageDim = 0.28
        let fontSize: Double = size == .large ? 24 : 18
        let caption = label("Your caption", name: "Caption", x: 0.5, y: 0.86, w: 0.86, h: 0.14, font: fontSize, weight: .bold, design: .rounded, align: .leading)
        return WidgetDesign(name: "Photo", size: size, background: background, elements: [caption])
    }

    // MARK: Device stats

    private static func device(_ size: WidgetSize) -> WidgetDesign {
        let dim = RGBAColor.white.withAlpha(0.85)
        let faint = RGBAColor.white.withAlpha(0.6)

        func stat(
            _ kind: DeviceStatKind, name: String,
            x: Double, y: Double, w: Double, h: Double,
            font: Double, weight: FontWeightOption = .semibold,
            color: RGBAColor = .white, align: TextAlignOption = .center
        ) -> DesignElement {
            var e = DesignElement.make(.device, in: size)
            e.name = name
            e.deviceStat = kind
            e.x = x; e.y = y; e.width = w; e.height = h
            e.fontSize = font
            e.weight = weight
            e.fontDesign = .rounded
            e.color = color
            e.alignment = align
            return e
        }

        var elements: [DesignElement]
        switch size {
        case .small:
            var icon = DesignElement.make(.symbol, in: size)
            icon.symbolName = "battery.75"
            icon.color = .white
            icon.x = 0.5
            icon.y = 0.22
            icon.setBox(width: 30, height: 30, in: size)
            elements = [
                icon,
                stat(.battery, name: "Battery", x: 0.5, y: 0.5, w: 0.92, h: 0.26, font: 34, weight: .bold),
                stat(.storage, name: "Storage", x: 0.5, y: 0.8, w: 0.94, h: 0.14, font: 12, weight: .medium, color: faint)
            ]
        case .medium:
            elements = [
                stat(.battery, name: "Battery", x: 0.27, y: 0.38, w: 0.46, h: 0.34, font: 42, weight: .bold, align: .leading),
                stat(.network, name: "Network", x: 0.27, y: 0.7, w: 0.46, h: 0.2, font: 15, color: dim, align: .leading),
                stat(.storage, name: "Storage", x: 0.76, y: 0.38, w: 0.44, h: 0.28, font: 14, align: .leading),
                stat(.uptime, name: "Uptime", x: 0.76, y: 0.64, w: 0.44, h: 0.2, font: 13, color: faint, align: .leading)
            ]
        case .large:
            elements = [
                stat(.battery, name: "Battery", x: 0.5, y: 0.2, w: 0.92, h: 0.22, font: 50, weight: .bold),
                stat(.storage, name: "Storage", x: 0.5, y: 0.46, w: 0.92, h: 0.12, font: 19, color: dim),
                stat(.network, name: "Network", x: 0.5, y: 0.62, w: 0.92, h: 0.12, font: 17, color: dim),
                stat(.uptime, name: "Uptime", x: 0.5, y: 0.78, w: 0.92, h: 0.12, font: 17, color: faint)
            ]
        }
        return WidgetDesign(name: "Device Stats", size: size, background: .gradient(0x232526, 0x0F2027, angle: 160), elements: elements)
    }

    // MARK: Glow clock

    private static func glow(_ size: WidgetSize) -> WidgetDesign {
        let background = DesignBackground(kind: .glow, colors: [RGBAColor(hex: 0xBFFF6B), RGBAColor(hex: 0x1E8E6B)], angle: 35)
        let dim = RGBAColor.white.withAlpha(0.85)

        var elements: [DesignElement]
        switch size {
        case .small:
            elements = [
                clockText(.time, name: "Time", x: 0.5, y: 0.42, w: 0.92, h: 0.3, font: 38, weight: .bold, design: .rounded),
                clockText(.weekdayShort, name: "Weekday", x: 0.5, y: 0.68, w: 0.9, h: 0.14, font: 16, color: dim)
            ]
        case .medium:
            var dial = DesignElement.make(.progress, in: size)
            dial.name = "Day gauge"
            dial.progressSource = .day
            dial.progressKind = .dial
            dial.color = RGBAColor(hex: 0xE9FFCB)
            dial.secondaryColor = RGBAColor.white.withAlpha(0.2)
            dial.lineWidth = 10
            dial.showsLabel = false
            dial.x = 0.78
            dial.y = 0.5
            dial.setBox(width: 92, height: 92, in: size)
            elements = [
                clockText(.time, name: "Time", x: 0.3, y: 0.42, w: 0.5, h: 0.4, font: 46, weight: .bold, design: .rounded, align: .leading),
                clockText(.weekdayShort, name: "Weekday", x: 0.3, y: 0.72, w: 0.5, h: 0.16, font: 17, color: dim, align: .leading),
                dial
            ]
        case .large:
            var dial = DesignElement.make(.progress, in: size)
            dial.name = "Day gauge"
            dial.progressSource = .day
            dial.progressKind = .dial
            dial.color = RGBAColor(hex: 0xE9FFCB)
            dial.secondaryColor = RGBAColor.white.withAlpha(0.2)
            dial.lineWidth = 14
            dial.x = 0.5
            dial.y = 0.64
            dial.setBox(width: 170, height: 170, in: size)
            elements = [
                clockText(.time, name: "Time", x: 0.5, y: 0.2, w: 0.92, h: 0.2, font: 48, weight: .bold, design: .rounded),
                clockText(.fullDate, name: "Date", x: 0.5, y: 0.34, w: 0.92, h: 0.1, font: 16, color: dim),
                dial
            ]
        }
        return WidgetDesign(name: "Glow Clock", size: size, background: background, elements: elements)
    }

    // MARK: Battery gauge

    private static func gauge(_ size: WidgetSize) -> WidgetDesign {
        let dim = RGBAColor.white.withAlpha(0.75)
        let green = RGBAColor(hex: 0x7CF2C5)

        var dial = DesignElement.make(.progress, in: size)
        dial.name = "Gauge"
        dial.progressSource = .battery
        dial.progressKind = .dial
        dial.color = green
        dial.secondaryColor = RGBAColor.white.withAlpha(0.16)
        dial.showsLabel = false

        var battery = DesignElement.make(.device, in: size)
        battery.name = "Battery"
        battery.deviceStat = .battery
        battery.weight = .bold
        battery.fontDesign = .rounded

        var elements: [DesignElement]
        switch size {
        case .small:
            dial.lineWidth = 11
            dial.x = 0.5; dial.y = 0.44
            dial.setBox(width: 108, height: 108, in: size)
            battery.fontSize = 22
            battery.x = 0.5; battery.y = 0.44; battery.width = 0.5; battery.height = 0.18
            elements = [
                dial, battery,
                label("Battery", name: "Caption", x: 0.5, y: 0.84, w: 0.8, h: 0.12, font: 12, weight: .medium, color: dim, uppercase: true)
            ]
        case .medium:
            dial.lineWidth = 13
            dial.x = 0.27; dial.y = 0.5
            dial.setBox(width: 118, height: 118, in: size)
            battery.fontSize = 24
            battery.x = 0.27; battery.y = 0.5; battery.width = 0.4; battery.height = 0.2
            var network = DesignElement.make(.device, in: size)
            network.name = "Network"
            network.deviceStat = .network
            network.color = dim
            network.fontDesign = .rounded
            network.fontSize = 15
            network.alignment = .leading
            network.x = 0.73; network.y = 0.56; network.width = 0.42; network.height = 0.16
            elements = [
                dial, battery,
                label("Battery", name: "Caption", x: 0.73, y: 0.34, w: 0.42, h: 0.14, font: 12, weight: .medium, color: dim, align: .leading, uppercase: true),
                network
            ]
        case .large:
            dial.lineWidth = 16
            dial.x = 0.5; dial.y = 0.38
            dial.setBox(width: 190, height: 190, in: size)
            battery.fontSize = 30
            battery.x = 0.5; battery.y = 0.38; battery.width = 0.6; battery.height = 0.14
            var storage = DesignElement.make(.device, in: size)
            storage.name = "Storage"
            storage.deviceStat = .storage
            storage.color = dim
            storage.fontDesign = .rounded
            storage.fontSize = 16
            storage.x = 0.5; storage.y = 0.8; storage.width = 0.85; storage.height = 0.1
            elements = [
                dial, battery,
                label("Battery", name: "Caption", x: 0.5, y: 0.66, w: 0.8, h: 0.08, font: 13, weight: .medium, color: dim, uppercase: true),
                storage
            ]
        }
        return WidgetDesign(name: "Battery Gauge", size: size, background: .solid(0x111318), elements: elements)
    }

    // MARK: Glass card

    private static func glass(_ size: WidgetSize) -> WidgetDesign {
        var panel = DesignElement.make(.shape, in: size)
        panel.name = "Glass panel"
        panel.shape = .rounded
        panel.isGlass = true
        panel.color = .white
        panel.cornerRadius = 22

        var time = DesignElement.make(.date, in: size)
        time.name = "Time"
        time.dateFormat = .time
        time.weight = .bold
        time.fontDesign = .rounded

        var caption = DesignElement.make(.formula, in: size)
        caption.name = "Status"
        caption.formulaSource = "{battery}% battery · {percent(dayProgress)} through today"
        caption.fontSize = 13
        caption.weight = .medium
        caption.color = RGBAColor.white.withAlpha(0.85)

        var elements: [DesignElement]
        switch size {
        case .small:
            panel.x = 0.5; panel.y = 0.5
            panel.setBox(width: 140, height: 140, in: size)
            time.x = 0.5; time.y = 0.4; time.width = 0.8; time.height = 0.26
            time.fontSize = 30
            caption.x = 0.5; caption.y = 0.66; caption.width = 0.8; caption.height = 0.22
            caption.fontSize = 11
            elements = [panel, time, caption]
        case .medium:
            panel.x = 0.5; panel.y = 0.5
            panel.setBox(width: 310, height: 130, in: size)
            time.x = 0.3; time.y = 0.42; time.width = 0.44; time.height = 0.3
            time.fontSize = 36
            time.alignment = .leading
            caption.x = 0.3; caption.y = 0.72; caption.width = 0.5; caption.height = 0.2
            caption.alignment = .leading
            elements = [panel, time, caption]
        case .large:
            panel.x = 0.5; panel.y = 0.26
            panel.setBox(width: 310, height: 160, in: size)
            time.x = 0.5; time.y = 0.2; time.width = 0.8; time.height = 0.24
            time.fontSize = 40
            caption.x = 0.5; caption.y = 0.36; caption.width = 0.8; caption.height = 0.14
            var panel2 = panel
            panel2.name = "Glass panel 2"
            panel2.y = 0.72
            panel2.setBox(width: 310, height: 160, in: size)
            var note = DesignElement.make(.text, in: size)
            note.name = "Note"
            note.text = "Edit this card's text and colors to match your own style."
            note.fontSize = 15
            note.alignment = .leading
            note.x = 0.5; note.y = 0.72; note.width = 0.8; note.height = 0.3
            elements = [panel, time, caption, panel2, note]
        }
        return WidgetDesign(name: "Glass Card", size: size, background: .gradient(0x2C3E50, 0x4CA1AF, angle: 150), elements: elements)
    }

    // MARK: Big numerals

    private static func bigDate(_ size: WidgetSize) -> WidgetDesign {
        var day = DesignElement.make(.date, in: size)
        day.name = "Day"
        day.dateFormat = .day
        day.weight = .heavy
        day.fontDesign = .rounded

        var weekday = DesignElement.make(.date, in: size)
        weekday.name = "Weekday"
        weekday.dateFormat = .weekday
        weekday.weight = .semibold
        weekday.isUppercase = true

        var month = DesignElement.make(.date, in: size)
        month.name = "Month"
        month.dateFormat = .month
        month.color = RGBAColor.white.withAlpha(0.7)

        var elements: [DesignElement]
        switch size {
        case .small:
            day.fontSize = 86
            day.x = 0.5; day.y = 0.44; day.width = 0.9; day.height = 0.5
            weekday.fontSize = 14
            weekday.x = 0.5; weekday.y = 0.78; weekday.width = 0.9; weekday.height = 0.14
            elements = [day, weekday]
        case .medium:
            day.fontSize = 110
            day.x = 0.3; day.y = 0.5; day.width = 0.46; day.height = 0.8
            weekday.fontSize = 18
            weekday.x = 0.74; weekday.y = 0.38; weekday.width = 0.42; weekday.height = 0.16
            weekday.alignment = .leading
            month.fontSize = 16
            month.x = 0.74; month.y = 0.56; month.width = 0.42; month.height = 0.14
            month.alignment = .leading
            elements = [day, weekday, month]
        case .large:
            day.fontSize = 190
            day.x = 0.5; day.y = 0.42; day.width = 0.95; day.height = 0.6
            weekday.fontSize = 24
            weekday.x = 0.5; weekday.y = 0.74; weekday.width = 0.9; weekday.height = 0.1
            month.fontSize = 20
            month.x = 0.5; month.y = 0.84; month.width = 0.9; month.height = 0.1
            elements = [day, weekday, month]
        }
        return WidgetDesign(name: "Big Numerals", size: size, background: .gradient(0xFDBB2D, 0x22C1C3, angle: 120), elements: elements)
    }
}
