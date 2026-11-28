import SwiftUI

private enum InspectorTab: String, CaseIterable, Identifiable {
    case content = "Content"
    case style = "Style"
    case layout = "Layout"

    var id: String { rawValue }
}

/// Property editor for the selected element.
struct InspectorPanel: View {
    @ObservedObject var model: EditorModel
    let element: DesignElement

    @State private var tab: InspectorTab = .content
    @State private var showSymbolPicker = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Picker("Section", selection: $tab) {
                ForEach(InspectorTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch tab {
                    case .content: contentControls
                    case .style: styleControls
                    case .layout: layoutControls
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showSymbolPicker) {
            SymbolPickerView(selection: bind(\.symbolName, element.symbolName))
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: Helpers

    private func bind<Value>(_ keyPath: WritableKeyPath<DesignElement, Value>, _ fallback: Value) -> Binding<Value> {
        model.binding(element.id, keyPath, fallback: fallback)
    }

    /// A few commonly-used values, offered as tappable chips in the Formula editor.
    private static let formulaVariables = [
        "battery", "charging", "storageUsedPercent", "uptimeHours",
        "day", "weekday", "dayProgress", "yearProgress", "online"
    ]

    private var formulaResult: Result<String, Error> {
        Result { try FormulaEngine.renderThrowing(element.formulaSource, now: Date()) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: element.kind.iconName)
                .foregroundStyle(Color.accentColor)
            Text(element.name)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            Button {
                model.duplicate(element.id)
            } label: {
                Image(systemName: "plus.square.on.square")
            }
            Button(role: .destructive) {
                model.delete(element.id)
            } label: {
                Image(systemName: "trash")
            }
            Button("Done") {
                model.selection = nil
            }
            .fontWeight(.semibold)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func actionButton(_ title: String, systemImage: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.footnote)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!enabled)
    }

    // MARK: Content tab

    @ViewBuilder private var contentControls: some View {
        switch element.kind {
        case .text:
            TextField("Text", text: bind(\.text, element.text), axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
            Toggle("Uppercase", isOn: bind(\.isUppercase, element.isUppercase))

        case .date:
            Picker("Format", selection: bind(\.dateFormat, element.dateFormat)) {
                ForEach(DateFormatOption.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.menu)
            if element.dateFormat == .custom {
                TextField("Pattern, e.g. EEEE d MMM", text: bind(\.customFormat, element.customFormat))
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Text("Shows: \(DesignContent.dateString(for: element, now: Date()))")
                .font(.footnote)
                .foregroundStyle(.secondary)

        case .countdown:
            DatePicker("Date", selection: bind(\.targetDate, element.targetDate), displayedComponents: .date)
            TextField("Label", text: bind(\.text, element.text))
                .textFieldStyle(.roundedBorder)
            Text("Use {n} for the days left, for example “{n} days to go”.")
                .font(.footnote)
                .foregroundStyle(.secondary)

        case .progress:
            Picker("Source", selection: bind(\.progressSource, element.progressSource)) {
                ForEach(ProgressSource.allCases) { source in
                    Text(source.title).tag(source)
                }
            }
            .pickerStyle(.menu)
            if element.progressSource == .manual {
                SliderRow(title: "Value", value: bind(\.progressValue, element.progressValue), range: 0...1, format: percentString)
            }
            Picker("Style", selection: bind(\.progressKind, element.progressKind)) {
                ForEach(ProgressKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            if element.progressKind == .ring || element.progressKind == .dial {
                Toggle("Show percentage", isOn: bind(\.showsLabel, element.showsLabel))
            }

        case .symbol:
            Button {
                showSymbolPicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: element.symbolName)
                        .font(.title2)
                        .frame(width: 36)
                    Text(element.symbolName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text("Change")
                        .font(.subheadline)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(.secondarySystemFill)))
            }
            .buttonStyle(.plain)

        case .shape:
            Picker("Shape", selection: bind(\.shape, element.shape)) {
                ForEach(ShapeKind.allCases) { shape in
                    Image(systemName: shape.iconName).tag(shape)
                }
            }
            .pickerStyle(.segmented)
            Toggle("Filled", isOn: bind(\.isFilled, element.isFilled))
            Toggle("Glass", isOn: bind(\.isGlass, element.isGlass))
            if element.isGlass {
                Text("A frosted, translucent panel — the Widgy-style glass look. Ignores Filled.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

        case .image:
            PhotoImportButton(maxDimension: 1000, onImported: { id in
                model.edit(element.id) { $0.imageID = id }
            }, label: {
                Label(element.imageID == nil ? "Choose Photo" : "Replace Photo", systemImage: "photo.on.rectangle")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(.secondarySystemFill)))
            })
            Picker("Fit", selection: bind(\.imageFit, element.imageFit)) {
                ForEach(ImageFit.allCases) { fit in
                    Text(fit.title).tag(fit)
                }
            }
            .pickerStyle(.segmented)

        case .device:
            Picker("Shows", selection: bind(\.deviceStat, element.deviceStat)) {
                ForEach(DeviceStatKind.allCases) { stat in
                    Text(stat.title).tag(stat)
                }
            }
            .pickerStyle(.menu)
            Text("Shows: \(DeviceStats.text(for: element.deviceStat))")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if element.deviceStat == .battery {
                Text("A Home Screen widget can't check the battery itself, so it shows the level from the last time you had WidgetForge open.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

        case .formula:
            TextField("Formula", text: bind(\.formulaSource, element.formulaSource), axis: .vertical)
                .lineLimit(2...6)
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Self.formulaVariables, id: \.self) { name in
                        Button("{\(name)}") {
                            model.edit(element.id) { $0.formulaSource += "{\(name)}" }
                        }
                        .font(.caption.monospaced())
                        .buttonStyle(.bordered)
                    }
                }
            }
            switch formulaResult {
            case .success(let text):
                Text("Shows: \(text)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .failure(let error):
                Text(error.localizedDescription)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            Text("Runs entirely on this device — it can only use the values above, never the network or another app. Combine them with + − × ÷, comparisons, and a condition ? if-true : if-false.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Style tab

    @ViewBuilder private var styleControls: some View {
        switch element.kind {
        case .text, .date, .countdown, .device, .formula:
            SliderRow(title: "Size", value: bind(\.fontSize, element.fontSize), range: 8...160)
            Picker("Weight", selection: bind(\.weight, element.weight)) {
                ForEach(FontWeightOption.allCases) { weight in
                    Text(weight.title).tag(weight)
                }
            }
            .pickerStyle(.menu)
            Picker("Font", selection: bind(\.fontDesign, element.fontDesign)) {
                ForEach(FontDesignOption.allCases) { design in
                    Text(design.title).tag(design)
                }
            }
            .pickerStyle(.segmented)
            Picker("Alignment", selection: bind(\.alignment, element.alignment)) {
                ForEach(TextAlignOption.allCases) { alignment in
                    Image(systemName: alignment.iconName).tag(alignment)
                }
            }
            .pickerStyle(.segmented)
            ColorRow(title: "Color", color: bind(\.color, element.color))

        case .progress:
            ColorRow(title: "Progress color", color: bind(\.color, element.color))
            ColorRow(title: "Track color", color: bind(\.secondaryColor, element.secondaryColor))
            SliderRow(title: "Thickness", value: bind(\.lineWidth, element.lineWidth), range: 2...60)

        case .symbol:
            Picker("Weight", selection: bind(\.weight, element.weight)) {
                ForEach(FontWeightOption.allCases) { weight in
                    Text(weight.title).tag(weight)
                }
            }
            .pickerStyle(.menu)
            ColorRow(title: "Color", color: bind(\.color, element.color))

        case .shape:
            ColorRow(title: "Color", color: bind(\.color, element.color))
            if !element.isFilled {
                SliderRow(title: "Line", value: bind(\.lineWidth, element.lineWidth), range: 1...30)
            }
            if element.shape == .rounded {
                SliderRow(title: "Corners", value: bind(\.cornerRadius, element.cornerRadius), range: 0...80)
            }

        case .image:
            SliderRow(title: "Corners", value: bind(\.cornerRadius, element.cornerRadius), range: 0...80)
        }
    }

    // MARK: Layout tab

    @ViewBuilder private var layoutControls: some View {
        SliderRow(title: "X", value: bind(\.x, element.x), range: 0...1, format: percentString)
        SliderRow(title: "Y", value: bind(\.y, element.y), range: 0...1, format: percentString)
        SliderRow(title: "Width", value: bind(\.width, element.width), range: 0.04...1.5, format: percentString)
        SliderRow(title: "Height", value: bind(\.height, element.height), range: 0.04...1.5, format: percentString)
        SliderRow(title: "Rotation", value: bind(\.rotation, element.rotation), range: -180...180) { "\(Int($0.rounded()))°" }
        SliderRow(title: "Opacity", value: bind(\.opacity, element.opacity), range: 0...1, format: percentString)

        HStack(spacing: 8) {
            actionButton("Center X", systemImage: "align.horizontal.center") {
                model.edit(element.id) { $0.x = 0.5 }
            }
            actionButton("Center Y", systemImage: "align.vertical.center") {
                model.edit(element.id) { $0.y = 0.5 }
            }
        }
        HStack(spacing: 8) {
            actionButton("Back", systemImage: "square.3.layers.3d.bottom.filled", enabled: model.canArrange(element.id, .back)) {
                model.arrange(element.id, .back)
            }
            actionButton("Down", systemImage: "square.2.layers.3d.bottom.filled", enabled: model.canArrange(element.id, .backward)) {
                model.arrange(element.id, .backward)
            }
            actionButton("Up", systemImage: "square.2.layers.3d.top.filled", enabled: model.canArrange(element.id, .forward)) {
                model.arrange(element.id, .forward)
            }
            actionButton("Front", systemImage: "square.3.layers.3d.top.filled", enabled: model.canArrange(element.id, .front)) {
                model.arrange(element.id, .front)
            }
        }
        Toggle("Lock position", isOn: bind(\.isLocked, element.isLocked))
    }
}
