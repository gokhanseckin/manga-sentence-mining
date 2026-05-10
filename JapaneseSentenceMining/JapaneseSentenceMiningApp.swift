import SwiftData
import SwiftUI

@main
struct JapaneseSentenceMiningApp: App {
    @State private var settings = SettingsStore()
    @State private var localization = LocalizationStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(localization)
                .task { await refreshStaleTranslationsIfNeeded() }
        }
        .modelContainer(AppModelContainer.shared)
    }

    /// Detects English-source-string changes since the cached translations
    /// were generated and silently re-translates only the changed keys. Runs
    /// once per launch.
    private func refreshStaleTranslationsIfNeeded() async {
        let stale = localization.staleKeys()
        guard !stale.isEmpty else { return }
        let key = settings.apiKey(for: .geminiFlash)
        guard !key.isEmpty else { return }
        do {
            let translator = InterfaceTranslator(apiKey: key)
            let translations = try await translator.translate(into: settings.interfaceLanguage)
            localization.install(translations: translations, for: settings.interfaceLanguage)
        } catch {
            print("Stale-key refresh failed: \(error)")
        }
    }
}

private struct RootView: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        if settings.hasCompletedOnboarding {
            HomeView()
        } else {
            OnboardingFlowView()
        }
    }
}
