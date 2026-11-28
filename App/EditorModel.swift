import SwiftUI

/// State and edit operations for the widget editor, including undo/redo and autosave.
final class EditorModel: ObservableObject {
    @Published var design: WidgetDesign {
        didSet { scheduleSave() }
    }
    @Published var selection: UUID?
    @Published var isPreviewing = false
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    /// Alignment guides shown while an element is dragged across the canvas centre.
    @Published var guideX = false
    @Published var guideY = false

    private var undoStack: [WidgetDesign] = []
    private var redoStack: [WidgetDesign] = []
    private var lastEditKey: String?
    private var lastEditDate = Date.distantPast
    private var pendingSave: DispatchWorkItem?
    private var isDirty = false
    private let persist: (WidgetDesign) -> Void

    init(design: WidgetDesign, persist: @escaping (WidgetDesign) -> Void) {
        self.design = design
        self.persist = persist
    }

    var selectedElement: DesignElement? {
        guard let selection else { return nil }
        return design.elements.first { $0.id == selection }
    }

    // MARK: Saving

    private func scheduleSave() {
        isDirty = true
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.flush()
        }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    /// Writes any unsaved changes immediately.
    func flush() {
        pendingSave?.cancel()
        pendingSave = nil
        guard isDirty else { return }
        isDirty = false
        persist(design)
    }

    // MARK: Undo / redo

    /// Records the current design as an undo step. Edits that share a `key` and arrive
    /// within a second of each other (a slider drag, typing) collapse into one step.
    private func registerUndo(key: String?) {
        let now = Date()
        if let key, key == lastEditKey, now.timeIntervalSince(lastEditDate) < 1.0 {
            lastEditDate = now
            return
        }
        lastEditKey = key
        lastEditDate = now
        undoStack.append(design)
        if undoStack.count > 100 {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        refreshUndoFlags()
    }

    /// Call once at the start of a drag, resize or rotate gesture.
    func beginInteraction() {
        registerUndo(key: nil)
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(design)
        design = previous
        lastEditKey = nil
        validateSelection()
        refreshUndoFlags()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(design)
        design = next
        lastEditKey = nil
        validateSelection()
        refreshUndoFlags()
    }

    private func refreshUndoFlags() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    private func validateSelection() {
        if let selection, !design.elements.contains(where: { $0.id == selection }) {
            self.selection = nil
        }
    }

    // MARK: Editing elements

    /// Applies a change to one element. Does nothing if the change is a no-op.
    func edit(
        _ id: UUID,
        key: String? = nil,
        registersUndo: Bool = true,
        _ change: (inout DesignElement) -> Void
    ) {
        guard let index = design.elements.firstIndex(where: { $0.id == id }) else { return }
        var element = design.elements[index]
        change(&element)
        guard element != design.elements[index] else { return }
        if registersUndo {
            registerUndo(key: key)
        }
        design.elements[index] = element
    }

    /// A binding to one property of an element, with undo coalescing built in.
    func binding<Value>(
        _ id: UUID,
        _ keyPath: WritableKeyPath<DesignElement, Value>,
        fallback: Value
    ) -> Binding<Value> {
        Binding(
            get: {
                self.design.elements.first(where: { $0.id == id })?[keyPath: keyPath] ?? fallback
            },
            set: { newValue in
                self.edit(id, key: "\(id)-\(String(describing: keyPath))") { element in
                    element[keyPath: keyPath] = newValue
                }
            }
        )
    }

    func backgroundBinding<Value>(_ keyPath: WritableKeyPath<DesignBackground, Value>) -> Binding<Value> {
        Binding(
            get: { self.design.background[keyPath: keyPath] },
            set: { newValue in
                var background = self.design.background
                background[keyPath: keyPath] = newValue
                self.setBackground(background, key: "background-\(String(describing: keyPath))")
            }
        )
    }

    func setBackground(_ background: DesignBackground, key: String? = nil) {
        guard background != design.background else { return }
        registerUndo(key: key)
        design.background = background
    }

    func rename(to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != design.name else { return }
        registerUndo(key: nil)
        design.name = trimmed
    }

    // MARK: Design Code

    /// Replaces the whole design from edited or pasted Design Code, keeping this design's own
    /// identity (its id and creation date) so the editor and library keep pointing at the same
    /// design afterwards rather than a second one appearing alongside it. Throws (and changes
    /// nothing) if the text doesn't parse, so a typo in the code editor is never a dead end.
    func applyCode(_ text: String) throws {
        var decoded = try DesignExchange.decodeDesign(from: text)
        decoded.id = design.id
        decoded.createdAt = design.createdAt
        decoded.modifiedAt = Date()
        guard decoded != design else { return }
        registerUndo(key: nil)
        design = decoded
        validateSelection()
    }

    // MARK: Adding and removing

    func add(_ element: DesignElement) {
        registerUndo(key: nil)
        design.elements.append(element)
        selection = element.id
    }

    func addElement(of kind: ElementKind) {
        add(DesignElement.make(kind, in: design.size))
    }

    func delete(_ id: UUID) {
        guard design.elements.contains(where: { $0.id == id }) else { return }
        registerUndo(key: nil)
        design.elements.removeAll { $0.id == id }
        if selection == id {
            selection = nil
        }
    }

    func duplicate(_ id: UUID) {
        guard let index = design.elements.firstIndex(where: { $0.id == id }) else { return }
        var copy = design.elements[index]
        copy.id = UUID()
        copy.name += " copy"
        copy.x = min(copy.x + 0.04, 0.95)
        copy.y = min(copy.y + 0.04, 0.95)
        registerUndo(key: nil)
        design.elements.insert(copy, at: index + 1)
        selection = copy.id
    }

    func setElementOrder(_ elements: [DesignElement]) {
        guard elements.map(\.id) != design.elements.map(\.id) else { return }
        registerUndo(key: nil)
        design.elements = elements
    }

    enum Arrangement {
        case forward, backward, front, back
    }

    func arrange(_ id: UUID, _ arrangement: Arrangement) {
        guard let index = design.elements.firstIndex(where: { $0.id == id }) else { return }
        let last = design.elements.count - 1
        let target: Int
        switch arrangement {
        case .forward: target = min(index + 1, last)
        case .backward: target = max(index - 1, 0)
        case .front: target = last
        case .back: target = 0
        }
        guard target != index else { return }
        registerUndo(key: nil)
        let element = design.elements.remove(at: index)
        design.elements.insert(element, at: target)
    }

    func canArrange(_ id: UUID, _ arrangement: Arrangement) -> Bool {
        guard let index = design.elements.firstIndex(where: { $0.id == id }) else { return false }
        switch arrangement {
        case .forward, .front: return index < design.elements.count - 1
        case .backward, .back: return index > 0
        }
    }
}
