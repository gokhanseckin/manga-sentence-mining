import CoreGraphics
import Foundation

enum ImagePreprocessorError: Error {
    case contextCreationFailed
}

/// Converts a CGImage crop into the `pixel_values` tensor data the manga-ocr
/// encoder expects: [1, 3, 224, 224] float32, CHW layout, normalized with
/// mean=[0.5,0.5,0.5] and std=[0.5,0.5,0.5] — i.e. `(px/255 - 0.5) / 0.5`.
struct ImagePreprocessor {
    static let target = 224

    static func makePixelValues(from cg: CGImage) throws -> Data {
        let side = target
        let bytesPerRow = side * 4
        let totalBytes = bytesPerRow * side
        let rgbaPtr = UnsafeMutableRawPointer.allocate(byteCount: totalBytes, alignment: 1)
        defer { rgbaPtr.deallocate() }
        memset(rgbaPtr, 255, totalBytes) // white background for any padding

        guard let cs = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw ImagePreprocessorError.contextCreationFailed
        }
        let info = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let ctx = CGContext(
            data: rgbaPtr,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: cs,
            bitmapInfo: info
        ) else {
            throw ImagePreprocessorError.contextCreationFailed
        }
        ctx.interpolationQuality = .high
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))

        let pixelCount = side * side
        var floats = [Float](repeating: 0, count: 3 * pixelCount)
        let rgba = rgbaPtr.assumingMemoryBound(to: UInt8.self)
        let scale = Float(1.0 / 127.5)
        for y in 0..<side {
            for x in 0..<side {
                let i = (y * side + x) * 4
                let p = y * side + x
                floats[p]                  = Float(rgba[i])     * scale - 1.0
                floats[pixelCount + p]     = Float(rgba[i + 1]) * scale - 1.0
                floats[2 * pixelCount + p] = Float(rgba[i + 2]) * scale - 1.0
            }
        }
        return floats.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
