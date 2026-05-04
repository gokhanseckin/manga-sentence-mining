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
        return try await provider.recognize(image: upright)
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
