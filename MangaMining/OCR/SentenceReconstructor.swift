import Foundation

/// Folds consecutive region texts into sentences. If a region's text doesn't end
/// in a sentence terminator, the next region is concatenated onto it.
struct SentenceReconstructor {
    private static let terminators: Set<Character> = [
        "。", "！", "？", "!", "?", "」", "』", "．", "."
    ]

    func reconstruct(orderedTexts: [String]) -> [String] {
        var out: [String] = []
        var buffer = ""
        for raw in orderedTexts {
            let piece = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !piece.isEmpty else { continue }
            buffer += piece
            if let last = buffer.last, Self.terminators.contains(last) {
                out.append(buffer)
                buffer = ""
            }
        }
        if !buffer.isEmpty {
            out.append(buffer)
        }
        return out
    }
}
