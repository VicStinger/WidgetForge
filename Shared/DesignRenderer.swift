import SwiftUI
import UIKit

// MARK: - Dynamic content

/// Computes the text and numbers that live elements display for a given moment.
enum DesignContent {
    static func dateString(for element: DesignElement, now: Date) -> String {
        switch element.dateFormat {
        case .time:
            return now.formatted(date: .omitted, time: .shortened)
        case .timeCompact:
            return now.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
        case .weekday:
            return now.formatted(.dateTime.weekday(.wide))
        case .weekdayShort:
            return now.formatted(.dateTime.weekday(.abbreviated))
        case .day:
            return now.formatted(.dateTime.day())
        case .monthDay:
            return now.formatted(.dateTime.month(.abbreviated).day())
        case .fullDate:
            return now.formatted(.dateTime.weekday(.wide).month(.wide).day())
        case .month:
            return now.formatted(.dateTime.month(.wide))
        case .year:
            return now.formatted(.dateTime.year())
        case .custom:
            let formatter = DateFormatter()
            formatter.dateFormat = element.customFormat
            return formatter.string(from: now)
        case .dayYesterday:
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
            return yesterday.formatted(.dateTime.day())
        case .dayTomorrow:
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
            return tomorrow.formatted(.dateTime.day())
        }
    }

    /// Whole calendar days between `now` and `target` (negative once the date has passed).
    static func daysRemaining(until target: Date, from now: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: target)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    static func countdownString(for element: DesignElement, now: Date) -> String {
        let days = max(0, daysRemaining(until: element.targetDate, from: now))
        let template = element.text.isEmpty ? "{n}" : element.text
        return template.replacingOccurrences(of: "{n}", with: String(days))
    }

    static func progressFraction(for element: DesignElement, now: Date) -> Double {
        switch element.progressSource {
        case .manual:
            return min(max(element.progressValue, 0), 1)
        case .storage:
            return DeviceStats.storageUsedFraction()
        case .battery:
            return min(max(Double(DeviceStats.batteryRaw().percent) / 100, 0), 1)
        case .day:
            return calendarFraction(.day, now: now)
        case .week:
            return calendarFraction(.weekOfYear, now: now)
        case .month:
            return calendarFraction(.month, now: now)
        case .year:
            return calendarFraction(.year, now: now)
        }
    }

    /// How far `now` is through the calendar period it falls in (0...1). Shared by Progress
    /// layers and by the Formula layer's `dayProgress`/`weekProgress`/... values.
    static func calendarFraction(_ component: Calendar.Component, now: Date) -> Double {
        guard let interval = Calendar.current.dateInterval(of: component, for: now),
              interval.duration > 0 else { return 0 }
        let elapsed = now.timeIntervalSince(interval.start) / interval.duration
        return min(max(elapsed, 0), 1)
    }

    static func text(for element: DesignElement, now: Date) -> String {
        switch element.kind {
        case .text: return element.text
        case .date: return dateString(for: element, now: now)
        case .countdown: return countdownString(for: element, now: now)
        case .device: return DeviceStats.text(for: element.deviceStat)
        case .formula: return FormulaEngine.render(element.formulaSource, now: now)
        default: return ""
        }
    }
}

// MARK: - Shape

struct ElementShape: Shape {
    var kind: ShapeKind
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        switch kind {
        case .rectangle:
            return Rectangle().path(in: rect)
        case .rounded:
            return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect)
        case .ellipse:
            return Ellipse().path(in: rect)
        case .capsule:
            return Capsule(style: .continuous).path(in: rect)
        }
    }
}

// MARK: - Background

struct BackgroundView: View {
    let background: DesignBackground

    var body: some View {
        switch background.kind {
        case .solid:
            (background.colors.first ?? RGBAColor.black).color
        case .linear:
            LinearGradient(colors: gradientColors, startPoint: startPoint, endPoint: endPoint)
        case .radial:
            GeometryReader { geo in
                RadialGradient(
                    colors: gradientColors,
                    center: .center,
                    startRadius: 0,
                    endRadius: max(geo.size.width, geo.size.height) * 0.75
                )
            }
        case .image:
            photo
        case .glow:
            glow
        }
    }

    private var gradientColors: [Color] {
        let colors = background.colors.map { $0.color }
        switch colors.count {
        case 0: return [Color.black, Color.black]
        case 1: return [colors[0], colors[0]]
        default: return colors
        }
    }

    /// Converts the angle (0 = up, 90 = right, 180 = down) into gradient end points that
    /// reach the corners of the canvas at 45°.
    private var startPoint: UnitPoint { points.start }
    private var endPoint: UnitPoint { points.end }

    private var points: (start: UnitPoint, end: UnitPoint) {
        let radians = background.angle * .pi / 180
        let dx = sin(radians)
        let dy = -cos(radians)
        let k = abs(dx) + abs(dy)
        let start = UnitPoint(x: 0.5 - dx * k / 2, y: 0.5 - dy * k / 2)
        let end = UnitPoint(x: 0.5 + dx * k / 2, y: 0.5 + dy * k / 2)
        return (start, end)
    }

    @ViewBuilder private var photo: some View {
        ZStack {
            if let id = background.imageID, let image = DesignStorage.loadImage(id) {
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                Color.black.opacity(background.imageDim)
            } else {
                LinearGradient(
                    colors: [Color(white: 0.22), Color(white: 0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    /// A dark base with soft, blurred color blobs — the glowing look behind many "Widgy"-style
    /// widgets. Reuses `colors` and repurposes `angle` as a shuffle seed for where the blobs sit.
    @ViewBuilder private var glow: some View {
        GeometryReader { geo in
            let colors = gradientColors
            ZStack {
                Color.black
                ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                    Circle()
                        .fill(color)
                        .frame(width: geo.size.width * 0.95, height: geo.size.width * 0.95)
                        .blur(radius: geo.size.width * 0.26)
                        .opacity(0.9)
                        .offset(blobOffset(index: index, count: colors.count, in: geo.size))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }

    private func blobOffset(index: Int, count: Int, in size: CGSize) -> CGSize {
        let seed = background.angle * .pi / 180
        let step = (2 * Double.pi) / Double(max(count, 1))
        let angle = seed + Double(index) * step
        let radius = min(size.width, size.height) * 0.3
        return CGSize(width: cos(angle) * radius, height: sin(angle) * radius)
    }
}

// MARK: - Canvas

/// Renders a design. Used by the widget, the library thumbnails and the editor.
struct DesignCanvasView: View {
    let design: WidgetDesign
    var date: Date = Date()
    var includesBackground: Bool = true

    var body: some View {
        GeometryReader { geo in
            let canvas = geo.size
            let ref = design.size.referenceSize
            let scale = min(canvas.width / ref.width, canvas.height / ref.height)
            ZStack(alignment: .topLeading) {
                if includesBackground {
                    BackgroundView(background: design.background)
                }
                ForEach(design.elements) { element in
                    if !element.isHidden {
                        ElementView(element: element, canvas: canvas, scale: scale, date: date)
                    }
                }
            }
            .frame(width: canvas.width, height: canvas.height)
            .clipped()
        }
    }
}

/// A design preview with the rounded corners of a real widget.
struct DesignThumbnail: View {
    let design: WidgetDesign

    var body: some View {
        DesignCanvasView(design: design)
            .aspectRatio(design.size.aspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Elements

struct ElementView: View {
    let element: DesignElement
    let canvas: CGSize
    let scale: CGFloat
    let date: Date

    private var boxWidth: CGFloat { max(1, CGFloat(element.width) * canvas.width) }
    private var boxHeight: CGFloat { max(1, CGFloat(element.height) * canvas.height) }

    var body: some View {
        content
            .opacity(element.opacity)
            .rotationEffect(.degrees(element.rotation))
            .position(x: CGFloat(element.x) * canvas.width, y: CGFloat(element.y) * canvas.height)
    }

    @ViewBuilder private var content: some View {
        switch element.kind {
        case .text, .date, .countdown, .device, .formula:
            textView(DesignContent.text(for: element, now: date))
        case .progress:
            ProgressElementView(element: element, box: CGSize(width: boxWidth, height: boxHeight), scale: scale, date: date)
        case .symbol:
            symbolView
        case .shape:
            shapeView
        case .image:
            imageView
        }
    }

    private func textView(_ string: String) -> some View {
        Text(string)
            .font(.system(
                size: max(1, CGFloat(element.fontSize) * scale),
                weight: element.weight.weight,
                design: element.fontDesign.design
            ))
            .textCase(element.isUppercase ? .uppercase : nil)
            .foregroundStyle(element.color.color)
            .multilineTextAlignment(element.alignment.textAlignment)
            .lineLimit(element.kind == .text ? nil : 1)
            .minimumScaleFactor(0.2)
            .frame(width: boxWidth, height: boxHeight, alignment: element.alignment.frameAlignment)
    }

    private var symbolView: some View {
        Image(systemName: element.symbolName)
            .font(.system(size: max(1, min(boxWidth, boxHeight) * 0.82), weight: element.weight.weight))
            .foregroundStyle(element.color.color)
            .frame(width: boxWidth, height: boxHeight)
    }

    @ViewBuilder private var shapeView: some View {
        let shape = ElementShape(kind: element.shape, cornerRadius: CGFloat(element.cornerRadius) * scale)
        if element.isGlass {
            glassShape(shape)
        } else if element.isFilled {
            shape.fill(element.color.color)
                .frame(width: boxWidth, height: boxHeight)
        } else {
            let line = max(1, CGFloat(element.lineWidth) * scale)
            shape.stroke(element.color.color, lineWidth: line)
                .padding(line / 2)
                .frame(width: boxWidth, height: boxHeight)
        }
    }

    /// A frosted-glass panel: a tinted translucent fill, a soft diagonal sheen, and a bright
    /// top edge — built from plain fills and gradients so it renders identically in the editor
    /// and in the widget, rather than depending on a live blur material.
    @ViewBuilder private func glassShape(_ shape: ElementShape) -> some View {
        ZStack {
            shape.fill(element.color.color.opacity(0.28))
            shape.fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.22), .clear, Color.white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            shape.stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.75), Color.white.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: max(1, 1.2 * scale)
            )
        }
        .frame(width: boxWidth, height: boxHeight)
    }

    @ViewBuilder private var imageView: some View {
        let radius = CGFloat(element.cornerRadius) * scale
        if let id = element.imageID, let image = DesignStorage.loadImage(id) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: element.imageFit == .fill ? .fill : .fit)
                .frame(width: boxWidth, height: boxHeight)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.white.opacity(0.14))
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: max(8, min(boxWidth, boxHeight) * 0.3)))
                        .foregroundStyle(Color.white.opacity(0.6))
                )
                .frame(width: boxWidth, height: boxHeight)
        }
    }
}

struct ProgressElementView: View {
    let element: DesignElement
    let box: CGSize
    let scale: CGFloat
    let date: Date

    private var fraction: Double { DesignContent.progressFraction(for: element, now: date) }
    private var line: CGFloat { max(1, CGFloat(element.lineWidth) * scale) }

    var body: some View {
        switch element.progressKind {
        case .ring:
            ring
        case .bar:
            bar
        case .dial:
            dial
        }
    }

    private var ring: some View {
        let diameter = max(1, min(box.width, box.height))
        return ZStack {
            Circle()
                .inset(by: line / 2)
                .stroke(element.secondaryColor.color, lineWidth: line)
            Circle()
                .inset(by: line / 2)
                .trim(from: 0, to: CGFloat(fraction))
                .stroke(element.color.color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if element.showsLabel {
                Text("\(Int((fraction * 100).rounded()))%")
                    .font(.system(size: diameter * 0.24, weight: element.weight.weight, design: element.fontDesign.design))
                    .foregroundStyle(element.color.color)
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
                    .padding(line + 2)
            }
        }
        .frame(width: diameter, height: diameter)
        .frame(width: box.width, height: box.height)
    }

    private var bar: some View {
        let thickness = min(box.height, line)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(element.secondaryColor.color)
                if fraction > 0 {
                    Capsule()
                        .fill(element.color.color)
                        .frame(width: max(geo.size.height, geo.size.width * CGFloat(fraction)))
                }
            }
        }
        .frame(width: box.width, height: thickness)
        .frame(width: box.width, height: box.height)
    }

    /// A speedometer-style gauge: a 270° arc with a 90° gap at the bottom, and a needle
    /// pointing at the current fraction — the dial look several "Widgy"-style widgets use for
    /// battery and progress.
    private var dial: some View {
        let diameter = max(1, min(box.width, box.height))
        let gaugeFraction = 0.75
        let baseRotation = -135.0
        let needleAngle = baseRotation + gaugeFraction * 360 * fraction
        return ZStack {
            Circle()
                .inset(by: line / 2)
                .trim(from: 0, to: gaugeFraction)
                .stroke(element.secondaryColor.color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(baseRotation))
            Circle()
                .inset(by: line / 2)
                .trim(from: 0, to: gaugeFraction * fraction)
                .stroke(element.color.color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(baseRotation))
            NeedleShape()
                .stroke(Color.white, style: StrokeStyle(lineWidth: max(1.5, line * 0.28), lineCap: .round))
                .padding(line * 1.6)
                .rotationEffect(.degrees(needleAngle))
            Circle()
                .fill(Color.white)
                .frame(width: max(3, line * 0.9), height: max(3, line * 0.9))
            if element.showsLabel {
                VStack(spacing: 0) {
                    Spacer()
                    Text("\(Int((fraction * 100).rounded()))%")
                        .font(.system(size: diameter * 0.16, weight: element.weight.weight, design: element.fontDesign.design))
                        .foregroundStyle(element.color.color)
                        .minimumScaleFactor(0.3)
                        .lineLimit(1)
                        .padding(.bottom, line * 0.4)
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .frame(width: box.width, height: box.height)
    }
}

/// A line from the center to the top edge, pointing "up" (0°) before any rotation — used as
/// the dial's needle.
private struct NeedleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }
}
