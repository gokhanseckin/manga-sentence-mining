import CoreGraphics
import Foundation
import UIKit

#if canImport(onnxruntime)
import onnxruntime
#endif

/// Runs the manga-ocr model on a single image crop and returns recognized text.
///
/// The mayocream/manga-ocr-onnx repo splits the model into a Vision Transformer
/// encoder and a GPT-style decoder. The encoder produces hidden states from a
/// 224x224 RGB image (ImageNet-normalized); the decoder autoregressively emits
/// token IDs that are decoded against the bundled vocab.
///
/// **Bundling:** the model files and tokenizer are not committed to the repo
/// (~440MB combined). Run `scripts/fetch-model.sh` to download them into
/// `MangaMining/Resources/` before building.
///
/// The ONNX inference loop is filled in during Phase 0 prototyping against a
/// real device — kept as a single implementation site, no protocol abstraction
/// (spec §5).
final class MangaOCRRunner: Sendable {
    enum RunnerError: Error {
        case modelMissing
        case vocabMissing
        case notImplemented
        case inferenceFailed(String)
    }

    static let shared = MangaOCRRunner()

    private init() {}

    var isAvailable: Bool {
        Bundle.main.url(forResource: "encoder_model", withExtension: "onnx") != nil
            && Bundle.main.url(forResource: "decoder_model", withExtension: "onnx") != nil
    }

    /// Recognize text in a CGImage crop. Returns "" if the crop has no readable text.
    /// Throws `.modelMissing` until the model files are added via the fetch script.
    func recognize(crop: CGImage) async throws -> String {
        guard Bundle.main.url(forResource: "encoder_model", withExtension: "onnx") != nil,
              Bundle.main.url(forResource: "decoder_model", withExtension: "onnx") != nil else {
            throw RunnerError.modelMissing
        }
        guard Bundle.main.url(forResource: "vocab", withExtension: "txt") != nil else {
            throw RunnerError.vocabMissing
        }
        // TODO(phase0): wire encoder → decoder loop with ORTSession.
        throw RunnerError.notImplemented
    }
}
