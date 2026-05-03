import CoreGraphics
import Foundation

#if canImport(OnnxRuntimeBindings)
import OnnxRuntimeBindings
#endif

/// Runs the manga-ocr VisionEncoderDecoder ONNX model on a single image crop.
///
/// Model layout (mayocream/manga-ocr-onnx):
/// - **Encoder** (`encoder_model.onnx`): DeiT-base patch16-224.
///     - input  `pixel_values` float32 [1, 3, 224, 224], normalized (px/127.5 - 1).
///     - output `last_hidden_state` float32 [1, 197, 768].
/// - **Decoder** (`decoder_model.onnx`): 2-layer BERT with cross-attention.
///     - inputs `input_ids` int64 [1, T] and `encoder_hidden_states` float32 [1, 197, 768].
///     - output `logits` float32 [1, T, 6144].
///
/// Phase 0 uses **plain greedy decoding** (no beam search, no n-gram repeat
/// constraint, no KV cache). The decoder is only 2 layers so the O(T²)
/// recompute is cheap enough; KV-cache and beam search are Phase 2 if needed.
///
/// Sessions are loaded lazily on first call and reused across recognitions.
/// ORT sessions are thread-safe for `run`, but the actor serializes anyway —
/// simpler than reasoning about concurrent decoder loops.
actor MangaOCRRunner {
    enum RunnerError: Error {
        case modelMissing
        case vocabMissing
        case ortUnavailable
        case inferenceFailed(String)
    }

    static let shared = MangaOCRRunner()

    private init() {}

    private struct Loaded {
        let env: ORTEnv
        let encoder: ORTSession
        let decoder: ORTSession
        let vocab: Vocab
    }

    private var loaded: Loaded?

    private static let decoderStartTokenID: Int64 = 2  // [CLS]
    private static let eosTokenID: Int64 = 3           // [SEP]
    private static let maxNewTokens: Int = 300
    private static let vocabSize: Int = 6144
    private static let encoderHiddenLen: Int = 197

    nonisolated var isAvailable: Bool {
        Bundle.main.url(forResource: "encoder_model", withExtension: "onnx") != nil
            && Bundle.main.url(forResource: "decoder_model", withExtension: "onnx") != nil
            && Bundle.main.url(forResource: "vocab", withExtension: "txt") != nil
    }

    private func ensureLoaded() throws -> Loaded {
        if let loaded { return loaded }

        guard let encURL = Bundle.main.url(forResource: "encoder_model", withExtension: "onnx"),
              let decURL = Bundle.main.url(forResource: "decoder_model", withExtension: "onnx") else {
            throw RunnerError.modelMissing
        }
        guard let vocabURL = Bundle.main.url(forResource: "vocab", withExtension: "txt") else {
            throw RunnerError.vocabMissing
        }

        do {
            let env = try ORTEnv(loggingLevel: .warning)
            let opts = try ORTSessionOptions()
            let encoder = try ORTSession(env: env, modelPath: encURL.path, sessionOptions: opts)
            let decoder = try ORTSession(env: env, modelPath: decURL.path, sessionOptions: opts)
            let vocab = try Vocab(contentsOf: vocabURL)
            let l = Loaded(env: env, encoder: encoder, decoder: decoder, vocab: vocab)
            self.loaded = l
            return l
        } catch let runnerError as RunnerError {
            throw runnerError
        } catch {
            throw RunnerError.inferenceFailed("session init: \(error.localizedDescription)")
        }
    }

    /// Recognize text in a CGImage crop. Returns the decoded string (may be empty).
    func recognize(crop: CGImage) async throws -> String {
        let loaded = try ensureLoaded()

        // Preprocess image into pixel_values tensor.
        let pixelData = try ImagePreprocessor.makePixelValues(from: crop)
        let pixelMutable = NSMutableData(data: pixelData)
        let pixelShape: [NSNumber] = [1, 3, 224, 224].map { NSNumber(value: $0) }
        let pixelTensor: ORTValue
        do {
            pixelTensor = try ORTValue(tensorData: pixelMutable, elementType: .float, shape: pixelShape)
        } catch {
            throw RunnerError.inferenceFailed("pixel tensor: \(error.localizedDescription)")
        }

        // Encoder pass.
        let encOutputs: [String: ORTValue]
        do {
            encOutputs = try loaded.encoder.run(
                withInputs: ["pixel_values": pixelTensor],
                outputNames: Set(["last_hidden_state"]),
                runOptions: nil
            )
        } catch {
            throw RunnerError.inferenceFailed("encoder run: \(error.localizedDescription)")
        }
        guard let encHidden = encOutputs["last_hidden_state"] else {
            throw RunnerError.inferenceFailed("missing encoder output")
        }

        // Greedy decode loop.
        var inputIDs: [Int64] = [Self.decoderStartTokenID]
        var output = ""
        let maxLen = Self.maxNewTokens
        let vocabSize = Self.vocabSize

        while inputIDs.count < maxLen {
            let idsData = inputIDs.withUnsafeBufferPointer { Data(buffer: $0) }
            let idsMutable = NSMutableData(data: idsData)
            let idsShape: [NSNumber] = [NSNumber(value: 1), NSNumber(value: inputIDs.count)]
            let idsTensor: ORTValue
            do {
                idsTensor = try ORTValue(tensorData: idsMutable, elementType: .int64, shape: idsShape)
            } catch {
                throw RunnerError.inferenceFailed("ids tensor: \(error.localizedDescription)")
            }

            let decOutputs: [String: ORTValue]
            do {
                decOutputs = try loaded.decoder.run(
                    withInputs: [
                        "input_ids": idsTensor,
                        "encoder_hidden_states": encHidden
                    ],
                    outputNames: Set(["logits"]),
                    runOptions: nil
                )
            } catch {
                throw RunnerError.inferenceFailed("decoder run: \(error.localizedDescription)")
            }
            guard let logits = decOutputs["logits"] else {
                throw RunnerError.inferenceFailed("missing decoder output")
            }

            let logitsData: NSMutableData
            do {
                logitsData = try logits.tensorData() as NSMutableData
            } catch {
                throw RunnerError.inferenceFailed("logits read: \(error.localizedDescription)")
            }

            // Argmax over the last sequence position.
            let T = inputIDs.count
            let lastOffsetFloats = (T - 1) * vocabSize
            var bestID: Int = 0
            var bestVal: Float = -.infinity
            logitsData.bytes.withMemoryRebound(to: Float.self, capacity: T * vocabSize) { ptr in
                let base = ptr.advanced(by: lastOffsetFloats)
                for i in 0..<vocabSize {
                    let v = base[i]
                    if v > bestVal {
                        bestVal = v
                        bestID = i
                    }
                }
            }

            if Int64(bestID) == Self.eosTokenID { break }
            inputIDs.append(Int64(bestID))
            if let piece = loaded.vocab.render(bestID) {
                output += piece
            }
        }

        return output
    }
}
