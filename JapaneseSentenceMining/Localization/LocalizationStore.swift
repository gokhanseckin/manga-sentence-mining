import Foundation
import Observation

/// Per-key translation cache for one language. `sourceHashes` stores the
/// SHA-256 of the English value at the moment each translation was
/// generated, so app updates can invalidate just the keys whose source has
/// changed.
struct TranslationCache: Codable, Sendable {
    var translations: [String: String]
    var sourceHashes: [String: String]
    var generatedAt: Date

    static let empty = TranslationCache(translations: [:], sourceHashes: [:], generatedAt: .distantPast)
}

@Observable
@MainActor
final class LocalizationStore {
    /// The active language code; for bundled languages this is one of
    /// `SupportedLanguage.rawValue`, for runtime-translated languages it can
    /// be any ISO-639-1 code.
    private(set) var activeLanguage: String = "en"

    /// Translations loaded for `activeLanguage`. Empty for English.
    private var cache: TranslationCache = .empty

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.languageKey) ?? Self.detectInitialLanguage()
        setLanguage(stored)
    }

    func t(_ key: String, _ args: CVarArg...) -> String {
        let template = resolved(key)
        if args.isEmpty { return template }
        return String(format: template, arguments: args)
    }

    func setLanguage(_ code: String) {
        activeLanguage = code
        UserDefaults.standard.set(code, forKey: Self.languageKey)
        cache = Self.loadCache(for: code) ?? .empty
    }

    /// Persist a fresh translation set (typically returned by Gemini) and
    /// switch to it.
    func install(translations: [String: String], for code: String) {
        var hashes: [String: String] = [:]
        for entry in BaseStrings.entries {
            hashes[entry.key] = BaseStrings.sourceHash(entry.value)
        }
        let new = TranslationCache(translations: translations, sourceHashes: hashes, generatedAt: .now)
        Self.saveCache(new, for: code)
        if code == activeLanguage {
            cache = new
        }
    }

    /// Returns the keys whose source has changed since the cached
    /// translations were generated. Empty if the cache is in sync.
    func staleKeys() -> [String] {
        guard activeLanguage != "en" else { return [] }
        var stale: [String] = []
        for entry in BaseStrings.entries {
            let currentHash = BaseStrings.sourceHash(entry.value)
            if cache.sourceHashes[entry.key] != currentHash {
                stale.append(entry.key)
            }
        }
        return stale
    }

    /// True if the cache lacks any translation for the active language and
    /// the language is not English. The onboarding flow uses this to decide
    /// whether to block on a translation.
    var requiresInitialTranslation: Bool {
        guard activeLanguage != "en" else { return false }
        return cache.translations.isEmpty
    }

    /// True if a non-empty translation cache exists on disk (bundled or
    /// Application Support) for the given language code. Used by onboarding
    /// to decide whether to skip the Gemini translation step.
    func hasCache(for code: String) -> Bool {
        guard code != "en" else { return true }
        guard let cached = Self.loadCache(for: code) else { return false }
        return !cached.translations.isEmpty
    }

    // MARK: - Resolution

    private func resolved(_ key: String) -> String {
        let englishFallback = BaseStrings.lookup[key]?.value ?? key
        guard activeLanguage != "en" else { return englishFallback }
        if let translated = cache.translations[key], !translated.isEmpty {
            return translated
        }
        return englishFallback
    }

    // MARK: - Persistence

    private static let languageKey = "interface_language_v1"

    private static func detectInitialLanguage() -> String {
        let preferred = Locale.preferredLanguages.first ?? "en"
        if let bundled = SupportedLanguage.bundled(matching: preferred) {
            return bundled.rawValue
        }
        return "en"
    }

    private static func cacheURL(for code: String) -> URL? {
        guard let dir = try? FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("InterfaceTranslations", isDirectory: true) else {
            return nil
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(code).json")
    }

    private static func loadCache(for code: String) -> TranslationCache? {
        // Bundled translations take precedence when a sandbox cache hasn't
        // been written yet (e.g. fresh install).
        if let bundled = loadBundled(code) { return bundled }
        guard let url = cacheURL(for: code), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TranslationCache.self, from: data)
    }

    private static func loadBundled(_ code: String) -> TranslationCache? {
        guard let url = Bundle.main.url(forResource: code, withExtension: "json", subdirectory: "InterfaceTranslations"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(TranslationCache.self, from: data) else {
            return nil
        }
        return decoded
    }

    private static func saveCache(_ cache: TranslationCache, for code: String) {
        guard let url = cacheURL(for: code) else { return }
        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: url, options: .atomic)
        } catch {
            print("LocalizationStore: failed to save cache: \(error)")
        }
    }
}
