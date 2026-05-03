import CoreGraphics
import Foundation
import Vision

/// Apple Vision text-region detection. We use Vision purely for bounding boxes,
/// not OCR — its Japanese vertical-text recognition is unreliable on manga.
///
/// `VNDetectTextRectanglesRequest` finds text regions from visual structure alone
/// (no language model), which catches stylized fonts and vertical layouts that
/// `VNRecognizeTextRequest` silently drops.
struct TextRegionDetector {
    /// Minimum normalized box area (fraction of image area) to keep. Filters out
    /// noise like page borders or single tiny artifacts. 0.0005 ≈ 0.05%.
    var minNormalizedArea: CGFloat = 0.0005

    /// Returns regions in image-pixel coordinates (origin top-left).
    func detect(cgImage: CGImage) async throws -> [CGRect] {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[CGRect], Error>) in
            let request = VNDetectTextRectanglesRequest { request, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNTextObservation]) ?? []
                let width = CGFloat(cgImage.width)
                let height = CGFloat(cgImage.height)
                let imageArea = width * height
                let minArea = imageArea * self.minNormalizedArea
                let rects: [CGRect] = observations.compactMap { obs in
                    let bb = obs.boundingBox
                    let x = bb.origin.x * width
                    let y = (1 - bb.origin.y - bb.size.height) * height
                    let w = bb.size.width * width
                    let h = bb.size.height * height
                    let rect = CGRect(x: x, y: y, width: w, height: h).integral
                    guard rect.width * rect.height >= minArea else { return nil }
                    return rect
                }
                cont.resume(returning: rects)
            }
            // We don't need per-character boxes — bubble-level regions only.
            request.reportCharacterBoxes = false

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                cont.resume(throwing: error)
            }
        }
    }
}
