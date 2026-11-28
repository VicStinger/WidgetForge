import SwiftUI

/// Generates a new design from a short text description, using the person's own Anthropic API
/// key. Entirely optional — with no key saved, this screen explains that and links out to get
/// one, rather than pretending AI generation is built in for free.
struct AIGenerateView: View {
    @EnvironmentObject private var library: DesignLibrary
    @Environment(\.dismiss) private var dismiss
    let onCreated: (WidgetDesign) -> Void

    @State private var apiKey: String = APIKeyStore.load() ?? ""
    @State private var model: String = AISettings.model
    @State private var prompt = ""
    @State private var size: WidgetSize = .small
    @State private var isGenerating = false
    @State private var errorMessage: String?

    let examples = [
        "A glowing green gradient with the time and a dial for how far through the day it is",
        "A frosted glass card showing battery percentage and free storage",
        "A bold, oversized day number on a warm sunset gradient"
    ]

    private var hasKey: Bool { !apiKey.trimmingCharacters(in: .whitespaces).isEmpty }
    private var hasPrompt: Bool { !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("API key (sk-ant-...)", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Link("Get a key at console.anthropic.com", destination: URL(string: "https://console.anthropic.com/settings/keys")!)
                        .font(.footnote)
                } header: {
                    Text("Anthropic API key")
                } footer: {
                    Text("Stored only on this device, in the Keychain. Generating sends your prompt directly from this device to Anthropic's API using this key, using your own account's credits — WidgetForge's authors never see it.")
                }

                if hasKey {
                    Section("Describe your widget") {
                        TextField("e.g. a glowing clock with a day-progress dial", text: $prompt, axis: .vertical)
                            .lineLimit(3...8)
                        ForEach(examples, id: \.self) { example in
                            Button {
                                prompt = example
                            } label: {
                                Text(example)
                                    .font(.footnote)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }

                    Section("Size") {
                        Picker("Size", selection: $size) {
                            ForEach(WidgetSize.allCases) { size in
                                Text(size.title).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section {
                        TextField("Model", text: $model)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.footnote.monospaced())
                    } header: {
                        Text("Model")
                    } footer: {
                        Text("Change this only if generation stops working after Anthropic renames their models.")
                    }

                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Generate with AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isGenerating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isGenerating {
                        ProgressView()
                    } else {
                        Button("Generate") { generate() }
                            .fontWeight(.semibold)
                            .disabled(!hasKey || !hasPrompt)
                    }
                }
            }
            .onChange(of: apiKey) { _, newValue in
                APIKeyStore.save(newValue)
            }
            .onChange(of: model) { _, newValue in
                AISettings.model = newValue
            }
        }
        .interactiveDismissDisabled(isGenerating)
    }

    private func generate() {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespaces)
        let trimmedModel = model.trimmingCharacters(in: .whitespaces)
        guard !trimmedKey.isEmpty else { return }
        isGenerating = true
        errorMessage = nil
        let resolvedModel = trimmedModel.isEmpty ? AISettings.defaultModel : trimmedModel
        let resolvedPrompt = prompt
        let resolvedSize = size

        Task {
            do {
                let text = try await AIDesignGenerator.generate(
                    prompt: resolvedPrompt, size: resolvedSize, model: resolvedModel, apiKey: trimmedKey
                )
                await MainActor.run {
                    isGenerating = false
                    switch library.importDesign(fromText: text) {
                    case .success(let design):
                        onCreated(design)
                        dismiss()
                    case .failure(let error):
                        errorMessage = "The model's reply didn't quite work: \(error.localizedDescription)"
                    }
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
