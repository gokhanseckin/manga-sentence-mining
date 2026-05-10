import SwiftUI

struct OnboardingFlowView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(LocalizationStore.self) private var localization

    @State private var step: Step = .welcome
    @State private var draftLanguage: String = ""
    @State private var draftApiKey: String = ""
    @State private var translationStatus: TranslationStatus = .idle

    enum Step: Hashable {
        case welcome
        case apiKey
        case language
    }

    enum TranslationStatus: Equatable {
        case idle
        case translating(language: String)
        case failed(message: String)
    }

    var body: some View {
        ZStack {
            NavigationStack {
                switch step {
                case .welcome:
                    WelcomeStepView(onContinue: { step = .apiKey })
                        .environment(localization)
                case .apiKey:
                    APIKeyStepView(
                        apiKey: $draftApiKey,
                        onContinue: handleApiKeyContinue
                    )
                    .environment(localization)
                case .language:
                    LanguageStepView(
                        selection: $draftLanguage,
                        translationStatus: translationStatus,
                        onContinue: handleLanguageContinue
                    )
                    .environment(localization)
                }
            }
            TranslationStatusOverlay(
                status: translationStatus,
                onRetry: { retryTranslation() },
                onContinueEnglish: { continueInEnglish() }
            )
            .environment(localization)
        }
        .onAppear {
            if draftLanguage.isEmpty {
                draftLanguage = settings.interfaceLanguage
            }
        }
    }

    private func handleApiKeyContinue() {
        let trimmed = draftApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        settings.setApiKey(trimmed, for: .geminiFlash)
        step = .language
    }

    private func handleLanguageContinue() {
        guard !draftLanguage.isEmpty else { return }
        settings.interfaceLanguage = draftLanguage

        if draftLanguage == "en" {
            localization.setLanguage(draftLanguage)
            settings.hasCompletedOnboarding = true
            return
        }

        if localization.hasCache(for: draftLanguage) {
            localization.setLanguage(draftLanguage)
            settings.hasCompletedOnboarding = true
            return
        }

        let key = settings.apiKey(for: .geminiFlash)
        guard !key.isEmpty else { return }
        translationStatus = .translating(language: draftLanguage)
        Task { await translateAndFinish(language: draftLanguage, apiKey: key) }
    }

    private func translateAndFinish(language: String, apiKey: String) async {
        let translator = InterfaceTranslator(apiKey: apiKey)
        do {
            let translations = try await translator.translate(into: language)
            localization.install(translations: translations, for: language)
            localization.setLanguage(language)
            translationStatus = .idle
            settings.hasCompletedOnboarding = true
        } catch {
            print("InterfaceTranslator failed: \(error)")
            translationStatus = .failed(message: error.localizedDescription)
        }
    }

    func retryTranslation() {
        let chosen = settings.interfaceLanguage
        let key = settings.apiKey(for: .geminiFlash)
        guard !key.isEmpty else { return }
        translationStatus = .translating(language: chosen)
        Task { await translateAndFinish(language: chosen, apiKey: key) }
    }

    func continueInEnglish() {
        settings.interfaceLanguage = "en"
        localization.setLanguage("en")
        translationStatus = .idle
        settings.hasCompletedOnboarding = true
    }
}

private struct LanguageStepView: View {
    @Environment(LocalizationStore.self) private var loc
    @Binding var selection: String
    let translationStatus: OnboardingFlowView.TranslationStatus
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(loc.t("onboarding.language.title"))
                .font(.largeTitle.bold())
                .padding(.top, 32)
            Text(loc.t("onboarding.language.body"))
                .foregroundStyle(.secondary)
            List {
                Section {
                    ForEach(SupportedLanguage.allCases, id: \.self) { language in
                        HStack {
                            Text(language.endonym)
                            Spacer()
                            if selection == language.rawValue {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selection = language.rawValue
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)

            Button {
                onContinue()
            } label: {
                Text(loc.t("onboarding.language.continue"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
            .disabled(selection.isEmpty)
        }
        .padding()
    }
}

private struct WelcomeStepView: View {
    @Environment(LocalizationStore.self) private var loc
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "text.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text(loc.t("onboarding.welcome.title"))
                .font(.largeTitle.bold())
            Text(loc.t("onboarding.welcome.body"))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                onContinue()
            } label: {
                Text(loc.t("onboarding.welcome.continue"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
        }
        .padding()
    }
}

private struct APIKeyStepView: View {
    @Environment(LocalizationStore.self) private var loc
    @Binding var apiKey: String
    let onContinue: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(loc.t("onboarding.apiKey.title"))
                .font(.largeTitle.bold())
                .padding(.top, 32)
            Text(loc.t("onboarding.apiKey.body"))
                .foregroundStyle(.secondary)

            SecureField(loc.t("onboarding.apiKey.placeholder"), text: $apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .focused($isFocused)

            Text(loc.t("onboarding.apiKey.privacy"))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                onContinue()
            } label: {
                Text(loc.t("onboarding.apiKey.continue"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .onAppear { isFocused = true }
    }
}

private struct TranslationStatusOverlay: View {
    @Environment(LocalizationStore.self) private var loc
    let status: OnboardingFlowView.TranslationStatus
    let onRetry: () -> Void
    let onContinueEnglish: () -> Void

    var body: some View {
        switch status {
        case .idle:
            EmptyView()
        case .translating:
            ZStack {
                Color.black.opacity(0.45).ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.4)
                    Text(loc.t("translation.inProgress.title"))
                        .font(.headline)
                    Text(loc.t("translation.inProgress.body"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(28)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                .padding(40)
            }
        case .failed(let message):
            ZStack {
                Color.black.opacity(0.45).ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(loc.t("translation.failed.title"))
                        .font(.headline)
                    Text(loc.t("translation.failed.body"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 12) {
                        Button(loc.t("translation.failed.retry"), action: onRetry)
                            .buttonStyle(.borderedProminent)
                        Button(loc.t("translation.failed.continueEnglish"), action: onContinueEnglish)
                            .buttonStyle(.bordered)
                    }
                    .padding(.top, 8)
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                .padding(32)
            }
        }
    }
}
