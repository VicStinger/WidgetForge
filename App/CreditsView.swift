import SwiftUI

/// The people behind WidgetForge.
struct CreditsView: View {
    struct Person: Identifiable {
        let name: String
        let role: String
        let symbol: String
        let tint: Color

        var id: String { name }
    }

    let people: [Person] = [
        Person(name: "Claude", role: "Main developer", symbol: "chevron.left.forwardslash.chevron.right", tint: .orange),
        Person(name: "VicStinger", role: "Backend & idea developer", symbol: "lightbulb.fill", tint: .indigo),
    ]

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        List {
            Section {
                header
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }

            Section {
                whatsNewRow("chevron.left.forwardslash.chevron.right", "Formula layers — a small, safe formula language for custom text, built from this device's own battery, date and progress values.")
                whatsNewRow("sparkles", "Glow backgrounds, dial gauges and frosted glass panels for a Widgy-style look.")
                whatsNewRow("square.grid.2x2", "Four new starting templates that show them off.")
                whatsNewRow("square.and.arrow.up", "Share a design as a file or as copyable \"Design Code\" — and import or paste one someone else shared with you.")
                whatsNewRow("character.cursor.ibeam", "View and hand-edit a design's own code, for anyone who'd rather type than drag.")
                whatsNewRow("wand.and.stars", "Generate a design from a short description, using your own Anthropic API key.")
            } header: {
                Text("What's new in 2.0")
            }

            Section {
                ForEach(people) { person in
                    row(person)
                }
            } header: {
                Text("Made by")
            } footer: {
                Text("Built with SwiftUI and WidgetKit.")
            }
        }
        .navigationTitle("Credits")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 76, height: 76)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                )
            Text("WidgetForge")
                .font(.title2.weight(.bold))
            Text("Design your own Home Screen widgets.")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
            Text(versionText)
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
        .padding(.vertical, 12)
    }

    private func row(_ person: Person) -> some View {
        HStack(spacing: 14) {
            Image(systemName: person.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.white)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(
                            colors: [person.tint, person.tint.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.headline)
                Text(person.role)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func whatsNewRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
        }
        .padding(.vertical, 2)
    }
}

/// The credits on their own screen, with a Done button. Used when opened from the library.
struct CreditsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CreditsView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}
