import CoreGraphics
import Foundation
import UIKit

#if canImport(onnxruntime)
import onnxruntime
#endif

/// Runs the manga-ocr ONNX model on a single image crop and returns recognized text.
///
/// The model expects a 224x224 RGB image normalized to ImageNet mean/std and produces
/// token IDs decoded via the bundled vocab.
///
/// **Bundling:** the model file (`manga-ocr.onnx`) and vocab (`vocab.txt`) are not
/// committed to the repo (~250MB combined). Run `scripts/fetch-model.sh` to download
/// them into `MangaMining/Resources/` before building.
///
/// This file is intentionally written as a stub with the integration shape in place.
/// The exact ONNX I/O signature and decoder loop are filled in during Phase 0
/// prototyping against a real device — they depend on which mayocream/manga-ocr-onnx
/// revision is bundled.
final class MangaOCRRunner {
    enum RunnerError: Error {
        case modelMissing
        case vocabMissing
        case notImplemented
        case inferenceFailed(String)
    }

    static let shared = MangaOCRRunner()

    private let modelResourceName = "manga-ocr"
    private let modelExtension = "onnx"
    private let vocabResourceName = "vocab"
    private let vocabExtension = "txt"

    private init() {}

    var isAvailable: Bool {
        Bundle.main.url(forResource: modelResourceName, withExtension: modelExtension) != nil
    }

    /// Recognize text in a CGImage crop. Returns "" if the crop has no readable text.
    /// Throws `.modelMissing` until the model file is added via the fetch script.
    func recognize(crop: CGImage) async throws -> String {
        guard let _ = Bundle.main.url(forResource: modelResourceName, withExtension: modelExtension) else {
            throw RunnerError.modelMissing
        }
        guard let _ = Bundle.main.url(forResource: vocabResourceName, withExtension: vocabExtension) else {
            throw RunnerError.vocabMissing
        }
        // TODO(phase0): implement ONNX inference path. Kept as a single
        // implementation site — no `OCREngine` protocol per spec §5.
        throw RunnerError.notImplemented
    }
}
