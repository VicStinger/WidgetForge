import SwiftUI
import WidgetKit

// MARK: - Entry

struct DesignEntry: TimelineEntry {
    let date: Date
    /// The design to draw, or nil when nothing is chosen yet.
    let design: WidgetDesign?
    /// The size of the widget on the Home Screen.
    let family: WidgetSize?
}

extension WidgetFamily {
    var designSize: WidgetSize? {
        switch self {
        case .systemSmall: return .small
        case .systemMedium: return .medium
        case .systemLarge: return .large
        default: return nil
        }
    }
}

// MARK: - Provider

struct DesignProvider: AppIntentTimelineProvider {
    typealias Entry = DesignEntry
    typealias Intent = SelectDesignIntent

    func placeholder(in context: Context) -> DesignEntry {
        let size = context.family.designSize ?? .small
        return DesignEntry(date: Date(), design: DesignTemplate.make(.clock, size: size), family: size)
    }

    func snapshot(for configuration: SelectDesignIntent, in context: Context) async -> DesignEntry {
        let family = context.family.designSize
        var design = resolveDesign(configuration, family: family)
        if design == nil, context.isPreview {
            // Widget gallery with no designs yet: show something attractive.
            design = DesignTemplate.make(.clock, size: family ?? .small)
        }
        return DesignEntry(date: Date(), design: design, family: family)
    }

    func timeline(for configuration: SelectDesignIntent, in context: Context) async -> Timeline<DesignEntry> {
        let family = context.family.designSize
        let design = resolveDesign(configuration, family: family)
        let dates = RefreshPlanner.entryDates(for: design, now: Date())
        let entries = dates.map { DesignEntry(date: $0, design: design, family: family) }
        return Timeline(entries: entries, policy: .atEnd)
    }

    /// The chosen design, or — if the widget hasn't been configured yet — the newest design
    /// that fits this widget's size.
    private func resolveDesign(_ configuration: SelectDesignIntent, family: WidgetSize?) -> WidgetDesign? {
        if let chosen = configuration.design {
            return DesignStorage.load(id: chosen.id)
        }
        guard let family else { return nil }
        return DesignStorage.loadAll().first { $0.size == family }
    }
}

// MARK: - View

struct DesignWidgetView: View {
    let entry: DesignEntry

    private var fitsFamily: Bool {
        guard let design = entry.design else { return false }
        guard let family = entry.family else { return true }
        return design.size == family
    }

    var body: some View {
        content
            .containerBackground(for: .widget) {
                background
            }
            .widgetURL(deepLink)
    }

    private var deepLink: URL? {
        guard let design = entry.design else { return nil }
        return URL(string: "widgetforge://design/\(design.id.uuidString)")
    }

    @ViewBuilder private var content: some View {
        if let design = entry.design {
            if fitsFamily {
                DesignCanvasView(design: design, date: entry.date, includesBackground: false)
            } else {
                message(
                    icon: "arrow.up.left.and.arrow.down.right",
                    title: "Wrong size",
                    detail: "\"\(design.name)\" is a \(design.size.title) design. Edit this widget and pick a \(entry.family?.title ?? "matching") one."
                )
            }
        } else {
            message(
                icon: "paintbrush.pointed",
                title: "Choose a design",
                detail: "Create one in WidgetForge, then touch and hold this widget and tap Edit Widget."
            )
        }
    }

    @ViewBuilder private var background: some View {
        if fitsFamily, let design = entry.design {
            BackgroundView(background: design.background)
        } else {
            LinearGradient(
                colors: [Color(white: 0.18), Color(white: 0.07)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func message(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(Color.white)
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Widget

struct WidgetForgeWidget: Widget {
    let kind = "WidgetForgeDesign"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectDesignIntent.self, provider: DesignProvider()) { entry in
            DesignWidgetView(entry: entry)
        }
        .configurationDisplayName("WidgetForge")
        .description("Shows a widget you designed in the WidgetForge app.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

@main
struct WidgetForgeBundle: WidgetBundle {
    var body: some Widget {
        WidgetForgeWidget()
    }
}
