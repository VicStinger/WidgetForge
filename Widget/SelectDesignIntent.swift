import AppIntents
import WidgetKit

/// A saved design, as shown in the "Edit Widget" picker.
struct DesignEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Design")
    static let defaultQuery = DesignQuery()

    let id: UUID
    let name: String
    let size: WidgetSize

    init(_ design: WidgetDesign) {
        self.id = design.id
        self.name = design.name
        self.size = design.size
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(size.title) widget")
    }
}

struct DesignQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [DesignEntity] {
        DesignStorage.loadAll()
            .filter { identifiers.contains($0.id) }
            .map { DesignEntity($0) }
    }

    func suggestedEntities() async throws -> [DesignEntity] {
        DesignStorage.loadAll().map { DesignEntity($0) }
    }
}

/// The configuration shown when you touch and hold the widget and choose Edit Widget.
struct SelectDesignIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Design"
    static let description = IntentDescription("Pick which of your WidgetForge designs this widget shows.")

    @Parameter(title: "Design")
    var design: DesignEntity?
}
