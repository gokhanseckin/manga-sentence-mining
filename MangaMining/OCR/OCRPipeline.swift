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
        guard let cg = image.cgImage else { throw OCRPipelineError.noImageData }
        let regions = try await detector.detect(cgImage: cg)
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
            guard !trimmed.isEmpty, !sfx.isSFX(trimmed) else { continue }
            perRegion.append((trimmed, rect))
        }

        let sentences = reconstructor.reconstruct(orderedTexts: perRegion.map(\.text))
        // Lossy: we don't track which subset of regions ended up in each sentence
        // post-reconstruction. Phase 0 doesn't need that mapping; storing all the
        // regions on each candidate keeps debugging simple.
        let allRegions = perRegion.map(\.rect)
        return sentences.map { SentenceCandidate(text: $0, sourceRegions: allRegions) }
    }
}
