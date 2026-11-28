import SwiftUI

/// Sheet for choosing a widget size and starting template.
struct NewDesignView: View {
    @EnvironmentObject private var library: DesignLibrary
    @Environment(\.dismiss) private var dismiss

    let onCreate: (WidgetDesign) -> Void

    @State private var size: WidgetSize = .small
    @State private var template: TemplateKind = .clock
    @State private var name = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    group("Size") {
                        Picker("Size", selection: $size) {
                            ForEach(WidgetSize.allCases) { size in
                                Text(size.title).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    group("Start from") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: size == .small ? 120 : 170), spacing: 14)], spacing: 16) {
                            ForEach(TemplateKind.allCases) { kind in
                                templateCard(kind)
                            }
                        }
                    }

                    group("Name (optional)") {
                        TextField(template.title, text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let design = library.create(size: size, template: template, name: name)
                        dismiss()
                        onCreate(design)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    private func templateCard(_ kind: TemplateKind) -> some View {
        let isSelected = kind == template
        return Button {
            template = kind
        } label: {
            VStack(spacing: 8) {
                DesignThumbnail(design: DesignTemplate.make(kind, size: size))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.accentColor, lineWidth: isSelected ? 3 : 0)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                VStack(spacing: 2) {
                    Text(kind.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Text(kind.subtitle)
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
