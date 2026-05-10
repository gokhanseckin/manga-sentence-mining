import Foundation

/// Calls Gemini once with the entire English source dictionary plus a
/// per-key translator comment, and parses a strict JSON map back. Used at
/// onboarding (blocking) and from Settings when the user changes language.
struct InterfaceTranslator: Sendable {
    let apiKey: String
    var session: URLSession = .shared

    static let model = "gemini-2.5-flash"
    static let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"

    enum TranslationError: LocalizedError {
        case missingApiKey
        case httpStatus(Int, String)
        case malformed(String)

        var errorDescription: String? {
            switch self {
            case .missingApiKey: "Add your Gemini API key in Settings to translate the interface."
            case .httpStatus(let code, let body): "Gemini HTTP \(code): \(body)"
            case .malformed(let snippet): "Gemini returned non-JSON: \(snippet.prefix(200))"
            }
        }
    }

    func translate(into languageCode: String) async throws -> [String: String] {
        guard !apiKey.isEmpty else { throw TranslationError.missingApiKey }

        let prompt = Self.buildPrompt(targetLanguage: languageCode)
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "temperature": 0,
                "responseMimeType": "application/json"
            ]
        ]

        var request = URLRequest(url: URL(string: "\(Self.endpoint)?key=\(apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let transient: Set<Int> = [429, 500, 502, 503, 504]
        let backoffs: [UInt64] = [1, 3, 7]
        var data = Data()
        var response: URLResponse?
        for attempt in 1...4 {
            (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                if (200..<300).contains(http.statusCode) { break }
                if transient.contains(http.statusCode), attempt < 4 {
                    try? await Task.sleep(nanoseconds: backoffs[attempt - 1] * 1_000_000_000)
                    continue
                }
                let snippet = String(data: data, encoding: .utf8)?.prefix(500) ?? ""
                throw TranslationError.httpStatus(http.statusCode, String(snippet))
            }
            break
        }

        struct Envelope: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String? }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }

        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard let raw = envelope.candidates.first?.content.parts.compactMap(\.text).first,
              let payload = raw.data(using: .utf8) else {
            throw TranslationError.malformed("empty response")
        }

        guard let parsed = try JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            throw TranslationError.malformed(raw)
        }
        var result: [String: String] = [:]
        for (key, value) in parsed {
            if let str = value as? String { result[key] = str }
        }
        return result
    }

    private static func buildPrompt(targetLanguage: String) -> String {
        let languageName = englishName(for: targetLanguage)
        var lines = [
            "You are translating UI strings for a Japanese-learning iOS app.",
            "Translate every value below into \(languageName) (BCP-47 code: \(targetLanguage)).",
            "Output values IN \(languageName), not in English.",
            "Preserve %@ placeholders verbatim and in the same position.",
            "Keep proper nouns (Japanese, Gemini, iCloud) untranslated unless the language has an established native name.",
            "Match button-style brevity in the target language. Use the comment as guidance.",
            "Return strict JSON: { \"key\": \"translated value\", ... } with no extra prose, no markdown.",
            "",
            "Strings:"
        ]
        for entry in BaseStrings.entries {
            lines.append("- key=\(entry.key)")
            lines.append("  english=\(entry.value)")
            lines.append("  comment=\(entry.comment)")
        }
        return lines.joined(separator: "\n")
    }

    private static func englishName(for code: String) -> String {
        let englishLocale = Locale(identifier: "en")
        if let name = englishLocale.localizedString(forIdentifier: code), !name.isEmpty {
            return name
        }
        if let name = englishLocale.localizedString(forLanguageCode: code), !name.isEmpty {
            return name
        }
        return code
    }
}
