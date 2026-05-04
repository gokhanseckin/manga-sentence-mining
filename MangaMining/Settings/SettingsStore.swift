import Foundation
import Observation

@Observable
@MainActor
final class SettingsStore {
    private let providerKey = "ocr_provider_kind"
    private let saveToCameraRollKey = "save_to_camera_roll"

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

    init() {
        if let raw = UserDefaults.standard.string(forKey: providerKey),
           let kind = OCRProviderKind(rawValue: raw) {
            self.providerKind = kind
        } else {
            self.providerKind = .geminiFlash
        }
        self.saveToCameraRoll = UserDefaults.standard.bool(forKey: saveToCameraRollKey)
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
            GeminiFlashProvider(apiKey: apiKey(for: .geminiFlash))
        }
    }
}
