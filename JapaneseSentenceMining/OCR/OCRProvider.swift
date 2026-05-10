import Foundation
import UIKit

protocol OCRProvider: Sendable {
    func recognize(image: UIImage) async throws -> OCRResult
}

struct OCRResult: Sendable {
    var documentType: DocumentType
    var sentences: [SentenceCandidate]
}

enum OCRProviderKind: String, CaseIterable, Identifiable, Sendable {
    case geminiFlash

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .geminiFlash: "Gemini 2.5 Flash"
        }
    }

    var keychainAccount: String {
        switch self {
        case .geminiFlash: "gemini_api_key"
        }
    }
}
