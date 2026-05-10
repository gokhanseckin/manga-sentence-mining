import SwiftUI

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(LocalizationStore.self) private var loc

    @State private var apiKeyDraft: String = ""
    @State private var savedFlash = false

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section(loc.t("settings.section.ocrProvider")) {
                Picker(loc.t("settings.providerPicker"), selection: $settings.providerKind) {
                    ForEach(OCRProviderKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.menu)
            }

            Section {
                Toggle(loc.t("settings.iCloudSync"), isOn: $settings.iCloudSyncEnabled)
            } header: {
                Text(loc.t("settings.section.iCloudSync"))
            } footer: {
                Text(loc.t("settings.iCloudSync.description"))
            }

            Section {
                Toggle(loc.t("settings.saveToCameraRoll"), isOn: $settings.saveToCameraRoll)
            } footer: {
                Text(loc.t("settings.saveToCameraRoll.footer"))
            }

            Section {
                Stepper(
                    loc.t("settings.sessionSize.label", String(settings.sessionSize)),
                    value: $settings.sessionSize,
                    in: SettingsStore.minSessionSize...SettingsStore.maxSessionSize
                )
                LabeledNumberField(label: loc.t("settings.review.alpha"), value: $settings.ebisuDefaultAlpha)
                LabeledNumberField(label: loc.t("settings.review.beta"), value: $settings.ebisuDefaultBeta)
                LabeledNumberField(label: loc.t("settings.review.tHours"), value: $settings.ebisuDefaultTHours)
            } header: {
                Text(loc.t("settings.section.review"))
            } footer: {
                Text(loc.t("settings.review.footer"))
            }

            Section {
                SecureField(loc.t("settings.apiKey.field.placeholder", settings.providerKind.displayName), text: $apiKeyDraft)
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
                        Text(savedFlash ? loc.t("settings.apiKey.saved") : loc.t("settings.apiKey.save"))
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
                        Label(loc.t("settings.apiKey.remove"), systemImage: "trash")
                    }
                }
            } header: {
                Text(loc.t("settings.section.apiKey"))
            } footer: {
                Text(loc.t("settings.apiKey.footer"))
            }
        }
        .navigationTitle(loc.t("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(loc.t("common.done")) { dismiss() }
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

private struct LabeledNumberField: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, value: $value, format: .number.precision(.fractionLength(0...3)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
        }
    }
}
