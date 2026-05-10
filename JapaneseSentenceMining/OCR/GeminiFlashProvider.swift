import Foundation
import UIKit

struct GeminiFlashProvider: OCRProvider {
    static let model = "gemini-2.5-flash"
    static let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
    static let maxLongEdge: CGFloat = 1568
    static let jpegQuality: CGFloat = 0.85

    let apiKey: String
    let targetLanguage: String
    var session: URLSession = .shared

    func recognize(image: UIImage) async throws -> OCRResult {
        guard !apiKey.isEmpty else { throw OCRPipelineError.apiKeyMissing }

        let downscaled = image.downscaled(maxLongEdge: Self.maxLongEdge)
        guard let jpeg = downscaled.jpegData(compressionQuality: Self.jpegQuality) else {
            throw OCRPipelineError.providerError(GeminiError.encodingFailed)
        }
        let pixelSize = CGSize(width: downscaled.size.width * downscaled.scale,
                               height: downscaled.size.height * downscaled.scale)

        var request = URLRequest(url: URL(string: "\(Self.endpoint)?key=\(apiKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: Self.body(jpegBase64: jpeg.base64EncodedString(),
                                      targetLanguage: targetLanguage)
        )

        let transientStatuses: Set<Int> = [429, 500, 502, 503, 504]
        let maxAttempts = 4
        let backoffsSeconds: [UInt64] = [1, 3, 7]

        var data: Data = Data()
        var response: URLResponse?
        for attempt in 1...maxAttempts {
            (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                if (200..<300).contains(http.statusCode) { break }
                if transientStatuses.contains(http.statusCode), attempt < maxAttempts {
                    let nanos = backoffsSeconds[attempt - 1] * 1_000_000_000
                    try? await Task.sleep(nanoseconds: nanos)
                    continue
                }
                let snippet = String(data: data, encoding: .utf8)?.prefix(500) ?? ""
                throw OCRPipelineError.providerError(GeminiError.httpStatus(http.statusCode, String(snippet)))
            }
            break
        }

        let envelope = try JSONDecoder().decode(GeminiEnvelope.self, from: data)
        guard let jsonText = envelope.candidates.first?.content.parts.compactMap(\.text).first else {
            throw OCRPipelineError.providerError(GeminiError.emptyResponse)
        }

        if let usage = envelope.usageMetadata {
            print("[OCR][gemini] tokens prompt=\(usage.promptTokenCount ?? 0) candidates=\(usage.candidatesTokenCount ?? 0) total=\(usage.totalTokenCount ?? 0)")
        }

        guard let payloadData = jsonText.data(using: .utf8) else {
            throw OCRPipelineError.providerError(GeminiError.malformedJSON(jsonText))
        }
        let payload = try JSONDecoder().decode(GeminiPayload.self, from: payloadData)
        let documentType = DocumentType(rawValue: payload.documentType) ?? .unknown

        let sentences = payload.sentences.compactMap { bubble -> SentenceCandidate? in
            let trimmed = bubble.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let rect = bubble.bbox.cgRect(in: pixelSize)
            return SentenceCandidate(
                text: trimmed,
                reading: "",
                translation: bubble.translation.trimmingCharacters(in: .whitespacesAndNewlines),
                sourceRegions: rect.map { [$0] } ?? []
            )
        }

        return OCRResult(documentType: documentType, sentences: sentences)
    }

    enum GeminiError: LocalizedError {
        case encodingFailed
        case httpStatus(Int, String)
        case emptyResponse
        case malformedJSON(String)

        var errorDescription: String? {
            switch self {
            case .encodingFailed: "Couldn't JPEG-encode the captured image."
            case .httpStatus(let code, let body): "Gemini HTTP \(code): \(body)"
            case .emptyResponse: "Gemini returned no candidates."
            case .malformedJSON(let s): "Gemini returned non-JSON content: \(s.prefix(200))"
            }
        }
    }

    private static func promptText(targetLanguage: String) -> String {
        let languageName = englishName(for: targetLanguage)
        return """
        You are extracting Japanese sentences from a printed page so a learner can mine vocabulary. The page may be MANGA (panels with speech bubbles, vertical text, sound effects, casual register) or PRINT (novel, newspaper, textbook, children's book — paragraphs, formal register, possibly inline furigana).

        STEP 1 — Classify the document. Set documentType to "manga" if the page has comic panels and speech bubbles, otherwise "print".

        STEP 2 — Extract sentences.

        For documentType = "manga":
        - Each speech bubble is one entry.
        - Order entries in natural reading order: top-right → bottom-left for vertical Japanese, top-left → bottom-right for horizontal.
        - Skip pure sound-effect bubbles (ドン, ガーン, ボッ, バン, ぐいっ, etc.).
        - Translation tone: conversational and informal. Preserve interjections, sentence-final particle nuance, and manga register.

        For documentType = "print":
        - Each natural sentence is one entry. Split on sentence-ending punctuation (。 ？ ！) but keep quotes and dialog tags together.
        - Order entries top-to-bottom in reading order. For vertical text on the printed page, top-right column first.
        - If furigana ruby is printed inline above kanji, IGNORE the furigana and transcribe only the base kanji.
        - Translation tone: faithful to the source register (formal in newspapers, narrative in novels, simple in children's books).

        For every entry:
        - text: TRANSCRIBE the original Japanese EXACTLY as printed. Do NOT rephrase, normalize particles, fix grammar, or change word order. Preserve every kanji, kana, punctuation mark, ellipsis (・・・, …), elongation (ー), and exclamation (!!, ！？).
        - translation: natural translation into \(languageName) (BCP-47 code: \(targetLanguage)). Output the translation IN \(languageName), not in English. Preserve tone.
        - bbox: [x, y, w, h] normalized 0–1 against the image, where the entry's text is located.

        Return ONLY the JSON object specified in the schema. No surrounding prose.
        """
    }

    /// Maps a BCP-47 / ISO-639 language code to its English name. Uses
    /// `Locale.current` to get the canonical English label so Gemini follows
    /// "translate into <Name>" rather than the raw code (which it sometimes
    /// ignores). Falls back to the code itself if Foundation can't resolve.
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

    private static func body(jpegBase64: String, targetLanguage: String) -> [String: Any] {
        [
            "contents": [[
                "parts": [
                    ["inline_data": ["mime_type": "image/jpeg", "data": jpegBase64]],
                    ["text": promptText(targetLanguage: targetLanguage)]
                ]
            ]],
            "generationConfig": [
                "temperature": 0,
                "responseMimeType": "application/json",
                "responseSchema": [
                    "type": "OBJECT",
                    "properties": [
                        "documentType": [
                            "type": "STRING",
                            "enum": ["manga", "print"]
                        ],
                        "sentences": [
                            "type": "ARRAY",
                            "items": [
                                "type": "OBJECT",
                                "properties": [
                                    "text": ["type": "STRING"],
                                    "translation": ["type": "STRING"],
                                    "bbox": [
                                        "type": "ARRAY",
                                        "items": ["type": "NUMBER"],
                                        "minItems": 4,
                                        "maxItems": 4
                                    ]
                                ],
                                "required": ["text", "translation", "bbox"]
                            ]
                        ]
                    ],
                    "required": ["documentType", "sentences"]
                ]
            ]
        ]
    }
}

private struct GeminiEnvelope: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable { let text: String? }
            let parts: [Part]
        }
        let content: Content
    }
    struct Usage: Decodable {
        let promptTokenCount: Int?
        let candidatesTokenCount: Int?
        let totalTokenCount: Int?
    }
    let candidates: [Candidate]
    let usageMetadata: Usage?
}

private struct GeminiPayload: Decodable {
    let documentType: String
    let sentences: [GeminiBubble]
}

private struct GeminiBubble: Decodable {
    let text: String
    let translation: String
    let bbox: [Double]
}

private extension Array where Element == Double {
    func cgRect(in size: CGSize) -> CGRect? {
        guard count == 4 else { return nil }
        let x = Swift.max(0, Swift.min(1, self[0]))
        let y = Swift.max(0, Swift.min(1, self[1]))
        let w = Swift.max(0, Swift.min(1 - x, self[2]))
        let h = Swift.max(0, Swift.min(1 - y, self[3]))
        return CGRect(x: x * size.width, y: y * size.height, width: w * size.width, height: h * size.height)
    }
}

private extension UIImage {
    func downscaled(maxLongEdge: CGFloat) -> UIImage {
        let longEdge = max(size.width, size.height)
        guard longEdge > maxLongEdge else { return self }
        let scale = maxLongEdge / longEdge
        let newSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
