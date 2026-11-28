import SwiftUI

// MARK: - Add panel (nothing selected)

struct AddPanel: View {
    @ObservedObject var model: EditorModel
    let onBackground: () -> Void
    let onLayers: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add to your widget")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ElementKind.allCases.filter { $0 != .image }) { kind in
                        Button {
                            model.addElement(of: kind)
                        } label: {
                            tile(icon: kind.iconName, title: kind.title)
                        }
                        .buttonStyle(.plain)
                    }
                    PhotoImportButton(maxDimension: 1000, onImported: { id in
                        var element = DesignElement.make(.image, in: model.design.size)
                        element.imageID = id
                        model.add(element)
                    }, label: {
                        tile(icon: "photo", title: "Photo")
                    })
                }
                .padding(.horizontal)
            }

            HStack(spacing: 10) {
                Button(action: onBackground) {
                    Label("Background", systemImage: "paintpalette")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: onLayers) {
                    Label("Layers", systemImage: "square.3.layers.3d")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)

            Spacer(minLength: 0)
        }
        .padding(.top, 12)
    }

    private func tile(icon: String, title: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
            Text(title)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(Color.primary)
        .frame(width: 74, height: 60)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemFill)))
    }
}

// MARK: - Background panel

struct BackgroundPanel: View {
    @ObservedObject var model: EditorModel
    let onDone: () -> Void

    struct Preset: Identifiable {
        let id = UUID()
        let background: DesignBackground
    }

    let presets: [Preset] = [
        Preset(background: .gradient(0x1D2671, 0xC33764)),
        Preset(background: .gradient(0xFF512F, 0xDD2476, angle: 150)),
        Preset(background: .gradient(0x134E5E, 0x71B280, angle: 160)),
        Preset(background: .gradient(0x141E30, 0x35577D, angle: 160)),
        Preset(background: .gradient(0xF7971E, 0xFFD200, angle: 135)),
        Preset(background: .gradient(0x4776E6, 0x8E54E9, angle: 135)),
        Preset(background: .gradient(0x232526, 0x414345, angle: 160)),
        Preset(background: .solid(0x111318)),
        Preset(background: .solid(0xF6EFE0)),
        Preset(background: .solid(0xFFFFFF)),
        Preset(background: DesignBackground(kind: .glow, colors: [RGBAColor(hex: 0xBFFF6B), RGBAColor(hex: 0x1E8E6B)], angle: 40)),
        Preset(background: DesignBackground(kind: .glow, colors: [RGBAColor(hex: 0xFF5F6D), RGBAColor(hex: 0x6B5FFF)], angle: 200)),
        Preset(background: DesignBackground(kind: .glow, colors: [RGBAColor(hex: 0x00C6FF), RGBAColor(hex: 0x7B2FF7)], angle: 110))
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "paintpalette")
                    .foregroundStyle(Color.accentColor)
                Text("Background")
                    .font(.headline)
                Spacer()
                Button("Done", action: onDone)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    presetRow

                    Picker("Type", selection: kindBinding) {
                        ForEach(BackgroundKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch model.design.background.kind {
                    case .solid:
                        ColorRow(title: "Color", color: colorBinding(0))
                    case .linear, .radial:
                        ColorRow(title: model.design.background.colors.count > 2 ? "Start" : "Color 1", color: colorBinding(0))
                        if model.design.background.colors.count > 2 {
                            ColorRow(title: "Middle", color: colorBinding(1))
                        }
                        ColorRow(title: model.design.background.colors.count > 2 ? "End" : "Color 2", color: colorBinding(lastColorIndex))
                        Toggle("Use three colors", isOn: threeColorsBinding)
                        if model.design.background.kind == .linear {
                            SliderRow(title: "Angle", value: model.backgroundBinding(\.angle), range: 0...360) { "\(Int($0.rounded()))°" }
                        }
                    case .glow:
                        ColorRow(title: "Color 1", color: colorBinding(0))
                        if model.design.background.colors.count > 2 {
                            ColorRow(title: "Color 2", color: colorBinding(1))
                        }
                        ColorRow(title: model.design.background.colors.count > 2 ? "Color 3" : "Color 2", color: colorBinding(lastColorIndex))
                        Toggle("Add a third color", isOn: threeColorsBinding)
                        Button {
                            var background = model.design.background
                            background.angle = Double.random(in: 0..<360)
                            model.setBackground(background)
                        } label: {
                            Label("Shuffle layout", systemImage: "shuffle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        Text("A dark base with soft, glowing color blobs — the look behind many Widgy-style widgets. Shuffle moves them around.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    case .image:
                        PhotoImportButton(maxDimension: 1400, onImported: { id in
                            var background = model.design.background
                            background.kind = .image
                            background.imageID = id
                            model.setBackground(background)
                        }, label: {
                            Label(model.design.background.imageID == nil ? "Choose Photo" : "Replace Photo", systemImage: "photo.on.rectangle")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(.secondarySystemFill)))
                        })
                        SliderRow(title: "Darken", value: model.backgroundBinding(\.imageDim), range: 0...0.85, format: percentString)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }

    private var presetRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(presets) { preset in
                    Button {
                        model.setBackground(preset.background)
                    } label: {
                        BackgroundView(background: preset.background)
                            .frame(width: 46, height: 46)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var lastColorIndex: Int {
        max(0, model.design.background.colors.count - 1)
    }

    /// Changes the background type, making sure gradients have at least two colours.
    private var kindBinding: Binding<BackgroundKind> {
        Binding(
            get: { model.design.background.kind },
            set: { newKind in
                var background = model.design.background
                background.kind = newKind
                if (newKind == .linear || newKind == .radial || newKind == .glow), background.colors.count < 2 {
                    let base = background.colors.first ?? RGBAColor.black
                    let darker = RGBAColor(r: base.r * 0.4, g: base.g * 0.4, b: base.b * 0.4, a: 1)
                    background.colors = [base, darker]
                }
                model.setBackground(background)
            }
        )
    }

    private func colorBinding(_ index: Int) -> Binding<RGBAColor> {
        Binding(
            get: {
                let colors = model.design.background.colors
                return index < colors.count ? colors[index] : RGBAColor.black
            },
            set: { newValue in
                var background = model.design.background
                while background.colors.count <= index {
                    background.colors.append(newValue)
                }
                background.colors[index] = newValue
                model.setBackground(background, key: "background-color-\(index)")
            }
        )
    }

    private var threeColorsBinding: Binding<Bool> {
        Binding(
            get: { model.design.background.colors.count > 2 },
            set: { isOn in
                var background = model.design.background
                if isOn, background.colors.count == 2 {
                    let a = background.colors[0]
                    let b = background.colors[1]
                    let middle = RGBAColor(r: (a.r + b.r) / 2, g: (a.g + b.g) / 2, b: (a.b + b.b) / 2, a: 1)
                    background.colors.insert(middle, at: 1)
                } else if !isOn, background.colors.count > 2 {
                    background.colors.remove(at: 1)
                }
                model.setBackground(background)
            }
        )
    }
}

// MARK: - Layers

struct LayersView: View {
    @ObservedObject var model: EditorModel
    @Environment(\.dismiss) private var dismiss

    /// Top-most layer first.
    private var displayed: [DesignElement] {
        Array(model.design.elements.reversed())
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(displayed) { element in
                    row(element)
                }
                .onMove { source, destination in
                    var list = displayed
                    list.move(fromOffsets: source, toOffset: destination)
                    model.setElementOrder(Array(list.reversed()))
                }
                .onDelete { offsets in
                    let ids = offsets.map { displayed[$0].id }
                    for id in ids {
                        model.delete(id)
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .overlay {
                if displayed.isEmpty {
                    ContentUnavailableView(
                        "No layers yet",
                        systemImage: "square.3.layers.3d",
                        description: Text("Add text, shapes and photos from the editor.")
                    )
                }
            }
            .navigationTitle("Layers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ element: DesignElement) -> some View {
        HStack(spacing: 12) {
            Button {
                model.selection = element.id
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: element.kind.iconName)
                        .frame(width: 24)
                        .foregroundStyle(Color.accentColor)
                    Text(element.name)
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    Spacer()
                }
            }
            .buttonStyle(.borderless)

            Button {
                model.edit(element.id) { $0.isLocked.toggle() }
            } label: {
                Image(systemName: element.isLocked ? "lock.fill" : "lock.open")
                    .foregroundStyle(element.isLocked ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.borderless)

            Button {
                model.edit(element.id) { $0.isHidden.toggle() }
            } label: {
                Image(systemName: element.isHidden ? "eye.slash" : "eye")
                    .foregroundStyle(element.isHidden ? Color.secondary : Color.accentColor)
            }
            .buttonStyle(.borderless)
        }
    }
}
