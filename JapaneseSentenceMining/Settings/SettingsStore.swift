import Foundation
import Observation

@Observable
@MainActor
final class SettingsStore {
    private let providerKey = "ocr_provider_kind"
    private let saveToCameraRollKey = "save_to_camera_roll"
    private let sessionSizeKey = "session_size"
    private let ebisuAlphaKey = "ebisu_default_alpha"
    private let ebisuBetaKey = "ebisu_default_beta"
    private let ebisuTHoursKey = "ebisu_default_t_hours"
    private let interfaceLanguageKey = "interface_language_v1"
    private let onboardingDoneKey = "onboarding_completed_at"
    private let iCloudSyncKey = AppModelContainer.iCloudSyncEnabledKey

    static let defaultSessionSize = 15
    static let minSessionSize = 1
    static let maxSessionSize = 50
    static let defaultEbisuAlpha = 3.0
    static let defaultEbisuBeta = 3.0
    static let defaultEbisuTHours = 24.0

    var providerKind: OCRProviderKind {
        didSet {
            UserDefaults.standard.set(providerKind.rawValue, forKey: providerKey)
        }
    }

    var saveToCameraRoll: Bool {
        didSet {
            UserDefaults.standard.set(saveToCameraRoll, forKey: saveToCameraRollKey)
        }
    }

    var sessionSize: Int {
        didSet {
            let clamped = min(max(sessionSize, Self.minSessionSize), Self.maxSessionSize)
            if clamped != sessionSize {
                sessionSize = clamped
                return
            }
            UserDefaults.standard.set(sessionSize, forKey: sessionSizeKey)
        }
    }

    var ebisuDefaultAlpha: Double {
        didSet { UserDefaults.standard.set(ebisuDefaultAlpha, forKey: ebisuAlphaKey) }
    }

    var ebisuDefaultBeta: Double {
        didSet { UserDefaults.standard.set(ebisuDefaultBeta, forKey: ebisuBetaKey) }
    }

    var ebisuDefaultTHours: Double {
        didSet { UserDefaults.standard.set(ebisuDefaultTHours, forKey: ebisuTHoursKey) }
    }

    /// ISO 639-1 (or `zh-Hans`) of the user's chosen language. Drives both
    /// the app's interface and the translation target for new captures.
    var interfaceLanguage: String {
        didSet { UserDefaults.standard.set(interfaceLanguage, forKey: interfaceLanguageKey) }
    }

    var hasCompletedOnboarding: Bool {
        didSet {
            if hasCompletedOnboarding {
                UserDefaults.standard.set(Date.now, forKey: onboardingDoneKey)
            } else {
                UserDefaults.standard.removeObject(forKey: onboardingDoneKey)
            }
        }
    }

    /// User-toggleable iCloud sync preference. Defaults to ON if the user is
    /// signed into iCloud at first launch.
    var iCloudSyncEnabled: Bool {
        didSet { UserDefaults.standard.set(iCloudSyncEnabled, forKey: iCloudSyncKey) }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: providerKey),
           let kind = OCRProviderKind(rawValue: raw) {
            self.providerKind = kind
        } else {
            self.providerKind = .geminiFlash
        }
        self.saveToCameraRoll = UserDefaults.standard.bool(forKey: saveToCameraRollKey)
        let storedSession = UserDefaults.standard.integer(forKey: sessionSizeKey)
        self.sessionSize = storedSession == 0 ? Self.defaultSessionSize : storedSession
        let storedAlpha = UserDefaults.standard.double(forKey: ebisuAlphaKey)
        self.ebisuDefaultAlpha = storedAlpha == 0 ? Self.defaultEbisuAlpha : storedAlpha
        let storedBeta = UserDefaults.standard.double(forKey: ebisuBetaKey)
        self.ebisuDefaultBeta = storedBeta == 0 ? Self.defaultEbisuBeta : storedBeta
        let storedT = UserDefaults.standard.double(forKey: ebisuTHoursKey)
        self.ebisuDefaultTHours = storedT == 0 ? Self.defaultEbisuTHours : storedT

        if let storedLang = UserDefaults.standard.string(forKey: interfaceLanguageKey) {
            self.interfaceLanguage = storedLang
        } else {
            let preferred = Locale.preferredLanguages.first ?? "en"
            self.interfaceLanguage = SupportedLanguage.bundled(matching: preferred)?.rawValue ?? "en"
        }

        self.hasCompletedOnboarding = UserDefaults.standard.object(forKey: onboardingDoneKey) != nil

        if UserDefaults.standard.object(forKey: iCloudSyncKey) != nil {
            self.iCloudSyncEnabled = UserDefaults.standard.bool(forKey: iCloudSyncKey)
        } else {
            self.iCloudSyncEnabled = FileManager.default.ubiquityIdentityToken != nil
        }
    }

    func apiKey(for kind: OCRProviderKind) -> String {
        KeychainStore.read(account: kind.keychainAccount) ?? ""
    }

    func setApiKey(_ value: String, for kind: OCRProviderKind) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainStore.delete(account: kind.keychainAccount)
        } else {
            KeychainStore.write(trimmed, account: kind.keychainAccount)
        }
    }

    func makeProvider() -> OCRProvider {
        switch providerKind {
        case .geminiFlash:
            GeminiFlashProvider(apiKey: apiKey(for: .geminiFlash), targetLanguage: interfaceLanguage)
        }
    }
}
