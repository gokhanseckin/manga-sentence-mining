import CoreGraphics
import Foundation
import Vision

/// Apple Vision text-region detection. We use Vision only for bounding boxes,
/// not its OCR output — Vision's Japanese vertical-text accuracy is poor on manga.
struct TextRegionDetector {
    /// Returns regions in image-pixel coordinates (origin top-left), sorted-pre.
    func detect(cgImage: CGImage) async throws -> [CGRect] {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[CGRect], Error>) in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let width = CGFloat(cgImage.width)
                let height = CGFloat(cgImage.height)
                let rects: [CGRect] = observations.map { obs in
                    // Vision uses normalized coords, origin bottom-left.
                    let bb = obs.boundingBox
                    let x = bb.origin.x * width
                    let y = (1 - bb.origin.y - bb.size.height) * height
                    let w = bb.size.width * width
                    let h = bb.size.height * height
                    return CGRect(x: x, y: y, width: w, height: h).integral
                }
                cont.resume(returning: rects)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ja", "ja-JP"]
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                cont.resume(throwing: error)
            }
        }
    }
}
