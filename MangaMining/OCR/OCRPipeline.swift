import CoreGraphics
import Foundation
import UIKit

struct SentenceCandidate: Identifiable, Hashable, Sendable {
    let id = UUID()
    var text: String
    var reading: String
    var translationTr: String
    var sourceRegions: [CGRect]
}

enum OCRPipelineError: LocalizedError {
    case noImageData
    case apiKeyMissing
    case providerError(Error)

    var errorDescription: String? {
        switch self {
        case .noImageData: "Couldn't read image data from the captured photo."
        case .apiKeyMissing: "Add your Gemini API key in Settings to recognize text."
        case .providerError(let err): err.localizedDescription
        }
    }
}

struct OCRPipeline {
    let provider: OCRProvider

    func process(image: UIImage) async throws -> [SentenceCandidate] {
        let upright = image.normalizedOrientation()
        guard upright.cgImage != nil else { throw OCRPipelineError.noImageData }
        var candidates = try await provider.recognize(image: upright)
        // Populate sentence reading from Mecab + IPADIC. The OCR provider no
        // longer asks the LLM for readings — Mecab is dictionary-grounded
        // and avoids LLM kun/on-yomi mistakes on kanji compounds.
        for index in candidates.indices where candidates[index].reading.isEmpty {
            if let reading = try? await JapaneseTokenizer.shared.hiraganaReading(of: candidates[index].text),
               !reading.isEmpty {
                candidates[index].reading = reading
            }
        }
        return candidates
    }
}

private extension UIImage {
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
