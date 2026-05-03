import CoreGraphics
import Foundation

enum ImagePreprocessorError: Error {
    case contextCreationFailed
}

/// Converts a CGImage crop into the `pixel_values` tensor data the manga-ocr
/// encoder expects: [1, 3, 224, 224] float32, CHW layout, normalized with
/// mean=[0.5,0.5,0.5] and std=[0.5,0.5,0.5] — i.e. `(px/127.5 - 1)`.
///
/// The model was trained on `PIL.Image.convert('L').convert('RGB')` inputs:
/// grayscale-first, then the single luminance channel replicated to all three
/// RGB channels. Feeding actual color produces gibberish output. We render
/// into a single-channel grayscale CGContext (PIL's L conversion uses the
/// same Rec. 601 luminance weights as Quartz's Gray colorspace) and fan the
/// gray bytes out to R/G/B identical floats.
struct ImagePreprocessor {
    static let target = 224

    static func makePixelValues(from cg: CGImage) throws -> Data {
        let side = target
        let totalBytes = side * side
        let grayPtr = UnsafeMutableRawPointer.allocate(byteCount: totalBytes, alignment: 1)
        defer { grayPtr.deallocate() }
        memset(grayPtr, 255, totalBytes) // white background for any padding

        guard let cs = CGColorSpace(name: CGColorSpace.linearGray) ?? CGColorSpace(name: CGColorSpace.genericGrayGamma2_2) else {
            throw ImagePreprocessorError.contextCreationFailed
        }
        guard let ctx = CGContext(
            data: grayPtr,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw ImagePreprocessorError.contextCreationFailed
        }
        ctx.interpolationQuality = .high

        // Preserve aspect ratio: fit the crop into a 224×224 box centered, with
        // white padding on the short axis. Vision returns per-column boxes for
        // vertical Japanese, which are tall and narrow; squashing those
        // directly destroys the character shapes and the model only recognizes
        // the first character before giving up. With aspect-preserving fit,
        // characters keep their natural proportions and the full column reads.
        let cropW = CGFloat(cg.width)
        let cropH = CGFloat(cg.height)
        let fit = min(CGFloat(side) / cropW, CGFloat(side) / cropH)
        let drawW = cropW * fit
        let drawH = cropH * fit
        let drawX = (CGFloat(side) - drawW) * 0.5
        let drawY = (CGFloat(side) - drawH) * 0.5
        ctx.draw(cg, in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))

        let pixelCount = side * side
        var floats = [Float](repeating: 0, count: 3 * pixelCount)
        let gray = grayPtr.assumingMemoryBound(to: UInt8.self)
        let scale = Float(1.0 / 127.5)
        for p in 0..<pixelCount {
            let v = Float(gray[p]) * scale - 1.0
            floats[p]                  = v
            floats[pixelCount + p]     = v
            floats[2 * pixelCount + p] = v
        }
        return floats.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
