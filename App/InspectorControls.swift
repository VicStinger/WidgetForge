import SwiftUI
import PhotosUI
import UIKit

// MARK: - Sliders

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var format: (Double) -> String = { String(Int($0.rounded())) }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline)
                .frame(width: 78, alignment: .leading)
            Slider(value: $value, in: range)
            Text(format(value))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
    }
}

func percentString(_ value: Double) -> String {
    "\(Int((value * 100).rounded()))%"
}

// MARK: - Colours

enum ColorPresets {
    static let all: [RGBAColor] = [
        RGBAColor(hex: 0xFFFFFF), RGBAColor(hex: 0x111318), RGBAColor(hex: 0x8E8E93),
        RGBAColor(hex: 0xFF453A), RGBAColor(hex: 0xFF9F0A), RGBAColor(hex: 0xFFD60A),
        RGBAColor(hex: 0x30D158), RGBAColor(hex: 0x7CF2C5), RGBAColor(hex: 0x64D2FF),
        RGBAColor(hex: 0x0A84FF), RGBAColor(hex: 0x5E5CE6), RGBAColor(hex: 0xBF5AF2),
        RGBAColor(hex: 0xFF375F), RGBAColor(hex: 0xAC8E68)
    ]
}

/// A colour well plus a row of quick swatches.
struct ColorRow: View {
    let title: String
    @Binding var color: RGBAColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                ColorPicker("", selection: pickerBinding, supportsOpacity: true)
                    .labelsHidden()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ColorPresets.all, id: \.self) { preset in
                        swatch(preset)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var pickerBinding: Binding<Color> {
        Binding(
            get: { color.color },
            set: { color = RGBAColor($0) }
        )
    }

    private func isSelected(_ preset: RGBAColor) -> Bool {
        abs(preset.r - color.r) < 0.01 && abs(preset.g - color.g) < 0.01 && abs(preset.b - color.b) < 0.01
    }

    private func swatch(_ preset: RGBAColor) -> some View {
        Button {
            color = RGBAColor(r: preset.r, g: preset.g, b: preset.b, a: color.a)
        } label: {
            Circle()
                .fill(preset.color)
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(Color.primary.opacity(0.25), lineWidth: 1))
                .padding(3)
                .overlay(
                    Circle().stroke(Color.accentColor, lineWidth: isSelected(preset) ? 2 : 0)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Symbols

struct SymbolPickerView: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    static let curated: [String] = [
        "sun.max.fill", "moon.stars.fill", "cloud.fill", "cloud.rain.fill", "bolt.fill", "snowflake",
        "flame.fill", "drop.fill", "leaf.fill", "tortoise.fill", "hare.fill", "pawprint.fill",
        "heart.fill", "star.fill", "sparkles", "crown.fill", "trophy.fill", "medal.fill",
        "flag.fill", "bookmark.fill", "tag.fill", "gift.fill", "balloon.fill", "party.popper.fill",
        "airplane", "car.fill", "bicycle", "figure.walk", "figure.run", "dumbbell.fill",
        "fork.knife", "cup.and.saucer.fill", "cart.fill", "bag.fill", "creditcard.fill", "dollarsign.circle.fill",
        "book.fill", "pencil", "paintbrush.fill", "graduationcap.fill", "briefcase.fill", "hammer.fill",
        "music.note", "headphones", "gamecontroller.fill", "camera.fill", "photo.fill", "film",
        "house.fill", "building.2.fill", "mappin.and.ellipse", "globe", "map.fill", "tent.fill",
        "calendar", "clock.fill", "alarm.fill", "timer", "hourglass", "bell.fill",
        "checkmark.circle.fill", "xmark.circle.fill", "exclamationmark.triangle.fill", "lightbulb.fill", "lock.fill", "key.fill",
        "phone.fill", "envelope.fill", "message.fill", "person.fill", "person.2.fill", "paperplane.fill",
        "chart.bar.fill", "chart.line.uptrend.xyaxis", "bed.double.fill", "moon.zzz.fill", "umbrella.fill", "pills.fill"
    ]

    private var results: [String] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return Self.curated }
        var matches = Self.curated.filter { $0.contains(trimmed) }
        // Allow any SF Symbol name that exists on this device.
        if !matches.contains(trimmed), UIImage(systemName: trimmed) != nil {
            matches.insert(trimmed, at: 0)
        }
        return matches
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 54), spacing: 10)], spacing: 10) {
                    ForEach(results, id: \.self) { name in
                        Button {
                            selection = name
                            dismiss()
                        } label: {
                            Image(systemName: name)
                                .font(.title2)
                                .frame(width: 54, height: 54)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(name == selection ? Color.accentColor.opacity(0.25) : Color(.secondarySystemFill))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                if results.isEmpty {
                    Text("No matches. Type an exact SF Symbol name to use it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .searchable(text: $query, prompt: "Search or type an SF Symbol name")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .navigationTitle("Symbol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Share sheet

/// Wraps `UIActivityViewController` (AirDrop, Messages, Mail, Files, ...) for SwiftUI, so
/// exporting a design's `.widgetforge` file can go straight to the system share sheet.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// A temporary exported file, identified by its path, for presenting `ActivityView` from a
/// `.sheet(item:)` — used by both the editor's "Share…" and the library's card menu.
struct ShareFile: Identifiable {
    let url: URL
    var id: String { url.path }
}

// MARK: - Photos

/// A button that opens the photo library, downsizes the chosen picture, stores it, and
/// reports the stored file's ID.
struct PhotoImportButton<Label: View>: View {
    var maxDimension: CGFloat = 1000
    var onImported: (String) -> Void
    @ViewBuilder var label: () -> Label

    @State private var item: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $item, matching: .images, photoLibrary: .shared()) {
            label()
        }
        .onChange(of: item) { _, newItem in
            guard let newItem else { return }
            let limit = maxDimension
            Task {
                var storedID: String?
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    // Decoding and resizing a full-size photo is slow, so keep it off the main thread.
                    storedID = await Task.detached(priority: .userInitiated) { () -> String? in
                        guard let image = UIImage(data: data) else { return nil }
                        return DesignStorage.saveImage(image, maxDimension: limit)
                    }.value
                }
                await MainActor.run {
                    if let storedID {
                        onImported(storedID)
                    }
                    item = nil
                }
            }
        }
    }
}
