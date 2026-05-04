import Foundation
import Observation

@Observable
@MainActor
final class SettingsStore {
    private let providerKey = "ocr_provider_kind"

    var providerKind: OCRProviderKind {
        didSet {
            UserDefaults.standard.set(providerKind.rawValue, forKey: providerKey)
        }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: providerKey),
           let kind = OCRProviderKind(rawValue: raw) {
            self.providerKind = kind
        } else {
            self.providerKind = .geminiFlash
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
            GeminiFlashProvider(apiKey: apiKey(for: .geminiFlash))
        }
    }
}
