import Foundation

/// ISO 639-1 codes (with `zh-Hans` for Simplified Chinese) bundled with the
/// app. These languages are pre-translated; any other language is translated
/// on demand via Gemini and cached to Application Support.
enum SupportedLanguage: String, CaseIterable, Sendable, Hashable {
    case english = "en"
    case french = "fr"
    case spanish = "es"
    case italian = "it"
    case turkish = "tr"
    case korean = "ko"
    case chinese = "zh-Hans"

    /// Native-language name shown in the language picker.
    var endonym: String {
        switch self {
        case .english: "English"
        case .french: "Français"
        case .spanish: "Español"
        case .italian: "Italiano"
        case .turkish: "Türkçe"
        case .korean: "한국어"
        case .chinese: "中文"
        }
    }

    var isLeftToRight: Bool { true }

    static func bundled(matching localeIdentifier: String) -> SupportedLanguage? {
        let lower = localeIdentifier.lowercased()
        let primary = lower.split(separator: "_").first.map(String.init) ?? lower
        let canonical = primary.split(separator: "-").first.map(String.init) ?? primary
        if canonical.hasPrefix("zh") { return .chinese }
        return SupportedLanguage(rawValue: canonical)
    }
}
