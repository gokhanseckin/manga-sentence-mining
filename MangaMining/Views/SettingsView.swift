import SwiftUI

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var apiKeyDraft: String = ""
    @State private var savedFlash = false

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("OCR provider") {
                Picker("Provider", selection: $settings.providerKind) {
                    ForEach(OCRProviderKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.menu)
            }

            Section {
                Toggle("Save photos to camera roll", isOn: $settings.saveToCameraRoll)
            } footer: {
                Text("When enabled, captured pages are also saved to your iOS Photos library.")
            }

            Section {
                SecureField("\(settings.providerKind.displayName) key", text: $apiKeyDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    settings.setApiKey(apiKeyDraft, for: settings.providerKind)
                    savedFlash = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        savedFlash = false
                    }
                } label: {
                    HStack {
                        Text(savedFlash ? "Saved" : "Save key")
                        if savedFlash {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                    }
                }
                .disabled(apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !settings.apiKey(for: settings.providerKind).isEmpty {
                    Button(role: .destructive) {
                        settings.setApiKey("", for: settings.providerKind)
                        apiKeyDraft = ""
                    } label: {
                        Label("Remove saved key", systemImage: "trash")
                    }
                }
            } header: {
                Text("API key")
            } footer: {
                Text("Keys are stored in the iOS Keychain on this device only.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            apiKeyDraft = settings.apiKey(for: settings.providerKind)
        }
        .onChange(of: settings.providerKind) { _, newKind in
            apiKeyDraft = settings.apiKey(for: newKind)
        }
    }
}
