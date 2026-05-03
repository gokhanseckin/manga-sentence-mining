import CoreGraphics
import Foundation
import UIKit
import Vision

/// Apple Vision text-region detection. We use Vision purely for bounding boxes,
/// not OCR — its Japanese recognition is unreliable on stylized manga text.
///
/// **Rotation trick:** `VNDetectTextRectanglesRequest` is designed to find
/// horizontal lines. For vertical Japanese, that means a single "line" spans
/// across multiple character columns at the same y-position — the resulting
/// crop contains the top character of column 1, the top of column 2, etc.,
/// and manga-ocr returns gibberish.
///
/// We rotate the page 90° CW before detection so vertical columns become
/// horizontal lines in the rotated frame, then translate boxes back to the
/// original frame. Each returned region is now a single vertical column.
///
/// We also detect on the unrotated image to catch genuinely horizontal text
/// (page headers, SFX, captions). Both result sets are unioned.
struct TextRegionDetector {
    var minNormalizedArea: CGFloat = 0.0005

    /// Returns regions in image-pixel coordinates (origin top-left).
    func detect(cgImage: CGImage) async throws -> [CGRect] {
        async let horizontalTask = detectOriented(cgImage: cgImage, rotateCW: false)
        async let verticalTask = detectOriented(cgImage: cgImage, rotateCW: true)
        let horizontal = try await horizontalTask
        let vertical = try await verticalTask
        return horizontal + vertical
    }

    private func detectOriented(cgImage: CGImage, rotateCW: Bool) async throws -> [CGRect] {
        let target: CGImage
        if rotateCW, let rotated = rotate90CW(cgImage) {
            target = rotated
        } else {
            target = cgImage
        }
        let raw = try await runVision(on: target)
        guard rotateCW else { return raw }
        let origH = CGFloat(cgImage.height)
        return raw.map { box in
            CGRect(
                x: box.origin.y,
                y: origH - box.origin.x - box.size.width,
                width: box.size.height,
                height: box.size.width
            ).integral
        }
    }

    private func runVision(on cg: CGImage) async throws -> [CGRect] {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[CGRect], Error>) in
            let request = VNDetectTextRectanglesRequest { request, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNTextObservation]) ?? []
                let width = CGFloat(cg.width)
                let height = CGFloat(cg.height)
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
            request.reportCharacterBoxes = false

            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            do {
                try handler.perform([request])
            } catch {
                cont.resume(throwing: error)
            }
        }
    }

    private func rotate90CW(_ cg: CGImage) -> CGImage? {
        // .right means "right edge is up", which renders as a 90° CW rotation.
        let img = UIImage(cgImage: cg, scale: 1, orientation: .right)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: img.size, format: format)
        return renderer.image { _ in
            img.draw(in: CGRect(origin: .zero, size: img.size))
        }.cgImage
    }
}
