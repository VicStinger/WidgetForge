import SwiftUI

/// Explains how to put a design on the Home Screen and reports whether sharing with the
/// widget extension is working.
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Add a widget to your Home Screen") {
                    step(1, "Touch and hold an empty spot on your Home Screen until the apps jiggle.")
                    step(2, "Tap the + button in the top-left corner and search for WidgetForge.")
                    step(3, "Pick the size that matches your design, tap Add Widget, then Done.")
                    step(4, "Touch and hold the new widget, choose Edit Widget, and select your design.")
                }

                Section("Good to know") {
                    tip("sparkles", "Changes you make in the editor appear on your Home Screen automatically.")
                    tip("square.on.square", "A design is made for one size. Pick a Small design for a Small widget, and so on.")
                    tip("hand.tap", "Tapping a widget opens its design here so you can keep tweaking it.")
                    tip("clock", "Clocks and progress rings refresh on a schedule set by iOS, so they can lag by a minute or two.")
                    tip("battery.75", "A Device layer shows this device's own battery, storage, uptime or connection. Battery can be a few minutes old in a widget; everything else is read live.")
                    tip("chevron.left.forwardslash.chevron.right", "A Formula layer runs a small, safe formula entirely on this device — combine battery, date and progress values with math and simple logic. It can't reach the network or any other app.")
                    tip("circle.dashed", "Progress layers can also draw as a dial gauge, Shape layers can get a frosted glass look, and backgrounds can glow — the Widgy-style options new in 2.0.")
                    tip("square.and.arrow.up", "Share any design from its \"…\" menu, or from the Library's context menu — as a file you can AirDrop or message, or as copyable \"Design Code\" text. Import a file, or paste a code someone sent you, from the Library's + menu.")
                    tip("wand.and.stars", "Generate with AI (from the + menu) writes a design from a short description, using your own Anthropic API key — entirely optional, and nothing is sent anywhere without one.")
                }

                Section("Setup status") {
                    HStack(spacing: 12) {
                        Image(systemName: AppGroup.isAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(AppGroup.isAvailable ? Color.green : Color.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(AppGroup.isAvailable ? "Widgets can read your designs" : "App Group not available")
                                .font(.subheadline.weight(.semibold))
                            Text(AppGroup.identifier)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            if !AppGroup.isAvailable {
                                Text("Add the App Groups capability to both the WidgetForge and WidgetForgeExtension targets, using the identifier above. See the README for details.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("About") {
                    NavigationLink {
                        CreditsView()
                    } label: {
                        Label("Credits", systemImage: "person.2.fill")
                    }
                }
            }
            .navigationTitle("How it works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Color.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.subheadline)
        }
        .padding(.vertical, 2)
    }

    private func tip(_ icon: String, _ text: String) -> some View {
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
