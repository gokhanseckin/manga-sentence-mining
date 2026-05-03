import Foundation

/// Drops onomatopoeia / sound effects using cheap linguistic heuristics.
/// Manga SFX tends to be: short, katakana-only (or mixed with elongation marks),
/// no kanji, no particles, no sentence-ending punctuation.
struct SFXFilter {
    var maxLengthForSFX: Int = 4

    private static let particles: Set<Character> = [
        "は", "が", "を", "に", "へ", "で", "と", "の", "も", "や", "か",
        "よ", "ね", "な", "ぞ", "ぜ", "わ", "さ", "し"
    ]

    private static let sentenceTerminators: Set<Character> = ["。", "！", "？", "!", "?", "」", "』"]

    func isSFX(_ raw: String) -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return true }
        if text.count > maxLengthForSFX { return false }

        var hasKanji = false
        var hasHiragana = false
        var hasTerminator = false
        for ch in text {
            if Self.sentenceTerminators.contains(ch) { hasTerminator = true }
            for scalar in ch.unicodeScalars {
                let v = scalar.value
                if (0x4E00...0x9FFF).contains(v) { hasKanji = true }
                if (0x3040...0x309F).contains(v) { hasHiragana = true }
            }
        }
        if hasKanji || hasTerminator { return false }
        if hasHiragana && text.contains(where: { Self.particles.contains($0) }) {
            return false
        }
        return true
    }

    func filter(_ texts: [String]) -> [String] {
        texts.filter { !isSFX($0) }
    }
}
