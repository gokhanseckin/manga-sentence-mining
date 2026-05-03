import CoreGraphics
import Foundation
import UIKit

struct SentenceCandidate: Identifiable, Hashable {
    let id = UUID()
    var text: String
    var sourceRegions: [CGRect]
}

enum OCRPipelineError: Error {
    case noImageData
    case noTextDetected
    case modelUnavailable
}

/// Orchestrates: Vision text-region detection → reading-order sort → manga-ocr per
/// region → SFX filter → sentence reconstruction.
///
/// Single concrete implementation. No `OCREngine` protocol abstraction (spec §5).
struct OCRPipeline {
    var detector = TextRegionDetector()
    var order = ReadingOrder()
    var sfx = SFXFilter()
    var reconstructor = SentenceReconstructor()
    var runner = MangaOCRRunner.shared

    func process(image: UIImage) async throws -> [SentenceCandidate] {
        // Camera photos arrive with EXIF orientation in the UIImage wrapper while
        // image.cgImage returns raw sensor pixels. Re-render to bake the
        // orientation into the pixels — otherwise Vision sees portrait shots as
        // sideways landscape and finds zero text regions.
        let upright = image.normalizedOrientation()
        guard let cg = upright.cgImage else { throw OCRPipelineError.noImageData }

        let regions = try await detector.detect(cgImage: cg)
        print("[OCR] Vision detected \(regions.count) text region(s) in \(cg.width)x\(cg.height) image")
        guard !regions.isEmpty else { throw OCRPipelineError.noTextDetected }
        let ordered = order.sort(regions, imageHeight: CGFloat(cg.height))

        var perRegion: [(text: String, rect: CGRect)] = []
        perRegion.reserveCapacity(ordered.count)
        for rect in ordered {
            guard let crop = cg.cropping(to: rect) else { continue }
            let raw: String
            do {
                raw = try await runner.recognize(crop: crop)
            } catch MangaOCRRunner.RunnerError.modelMissing,
                    MangaOCRRunner.RunnerError.vocabMissing {
                throw OCRPipelineError.modelUnavailable
            }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            print("[OCR] region \(rect) → \"\(trimmed)\"")
            guard !trimmed.isEmpty, !sfx.isSFX(trimmed), !isOnlyPunctuation(trimmed) else { continue }
            perRegion.append((trimmed, rect))
        }

        let sentences = reconstructor.reconstruct(orderedTexts: perRegion.map(\.text))
        let allRegions = perRegion.map(\.rect)
        return sentences.map { SentenceCandidate(text: $0, sourceRegions: allRegions) }
    }
}

/// True if the string contains nothing but ellipsis / dots / Japanese punctuation.
/// manga-ocr emits these for noise-only crops (small artifacts, partial bubble
/// borders), and they aren't useful as study sentences.
private func isOnlyPunctuation(_ s: String) -> Bool {
    let punctuation: Set<Character> = [".", "。", "、", "・", "…", "‥", "ー", "「", "」", "『", "』", "！", "？", "!", "?", " ", "\t"]
    return s.allSatisfy { punctuation.contains($0) }
}

private extension UIImage {
    /// Re-renders the image with .up orientation so the underlying CGImage
    /// matches what the user actually sees.
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
