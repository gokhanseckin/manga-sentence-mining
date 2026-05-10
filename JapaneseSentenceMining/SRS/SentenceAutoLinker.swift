import Foundation
import SwiftData

@MainActor
enum SentenceAutoLinker {
    /// For each newly-ingested sentence, tokenizes the text and creates a
    /// non-excluded `Cloze` for every token whose lemma matches an existing
    /// `WordCard`. The `WordCard`'s SRS schedule is unchanged — the new sentence
    /// just joins its delivery pool.
    static func autoLink(sentences: [Sentence], in context: ModelContext) async {
        guard !sentences.isEmpty else { return }
        let cards = (try? context.fetch(FetchDescriptor<WordCard>())) ?? []
        guard !cards.isEmpty else { return }
        // CloudKit sync removed the @Attribute(.unique) on lemma so two devices
        // could each create a card for the same lemma offline. Picking the
        // first one keeps the linker safe; downstream merge logic dedupes.
        let cardByLemma = Dictionary(cards.map { ($0.lemma, $0) }, uniquingKeysWith: { first, _ in first })

        for sentence in sentences {
            let text = sentence.text
            guard let tokens = try? await JapaneseTokenizer.shared.tokenize(text) else { continue }
            for token in tokens {
                guard let card = cardByLemma[token.lemma] else { continue }
                let start = text.distance(from: text.startIndex, to: token.range.lowerBound)
                let end = text.distance(from: text.startIndex, to: token.range.upperBound)
                if sentence.clozes.contains(where: { $0.startOffset == start && $0.endOffset == end }) {
                    continue
                }
                let cloze = Cloze(
                    sentence: sentence,
                    wordCard: card,
                    startOffset: start,
                    endOffset: end,
                    surfaceForm: token.surface,
                    lemma: token.lemma,
                    reading: token.reading,
                    partOfSpeech: token.partOfSpeech
                )
                context.insert(cloze)
                card.addSnapshot(SourceSnapshot(
                    sentenceText: sentence.text,
                    reading: sentence.reading ?? "",
                    translation: sentence.translation ?? "",
                    translationLanguage: sentence.translationLanguage,
                    pageId: sentence.capturedPage?.id,
                    capturedAt: sentence.createdAt
                ))
            }
        }
        try? context.save()
    }

    /// Inverse direction: a word was just clozed. Scan every existing sentence
    /// for tokens matching `card.lemma` and create non-excluded Cloze rows for
    /// any occurrences that don't already have one. Used when the user picks a
    /// cloze for the first time so older sentences containing the word
    /// retroactively join the card's pool.
    static func autoLink(card: WordCard, in context: ModelContext) async {
        let sentences = (try? context.fetch(FetchDescriptor<Sentence>())) ?? []
        guard !sentences.isEmpty else { return }
        let lemma = card.lemma
        var changed = false
        for sentence in sentences {
            let text = sentence.text
            guard let tokens = try? await JapaneseTokenizer.shared.tokenize(text) else { continue }
            for token in tokens where token.lemma == lemma {
                let start = text.distance(from: text.startIndex, to: token.range.lowerBound)
                let end = text.distance(from: text.startIndex, to: token.range.upperBound)
                if sentence.clozes.contains(where: { $0.startOffset == start && $0.endOffset == end }) {
                    continue
                }
                let cloze = Cloze(
                    sentence: sentence,
                    wordCard: card,
                    startOffset: start,
                    endOffset: end,
                    surfaceForm: token.surface,
                    lemma: token.lemma,
                    reading: token.reading,
                    partOfSpeech: token.partOfSpeech
                )
                context.insert(cloze)
                card.addSnapshot(SourceSnapshot(
                    sentenceText: sentence.text,
                    reading: sentence.reading ?? "",
                    translation: sentence.translation ?? "",
                    translationLanguage: sentence.translationLanguage,
                    pageId: sentence.capturedPage?.id,
                    capturedAt: sentence.createdAt
                ))
                changed = true
            }
        }
        if changed { try? context.save() }
    }
}
