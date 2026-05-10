import Foundation
import SwiftData

@MainActor
enum AnswerOptionsBuilder {
    /// Builds four shuffled answer options for the given cloze question.
    ///
    /// Distractor algorithm (spec §1, §2, §6 brief):
    ///   1. Candidate pool = all `Cloze` rows whose `lemma != currentCloze.lemma`
    ///      (also dedupe by `surfaceForm` so we don't show the same word twice).
    ///   2. Filter by `partOfSpeech == currentCloze.partOfSpeech`.
    ///   3. Filter by `abs(surface.count - target.count) <= 1`.
    ///   4. Shuffle, take 3. If fewer than 3, relax the length filter, then
    ///      the POS filter, until 3 are found. If pool still too small, fill
    ///      remaining slots with random other clozes.
    ///   5. Combine with the correct answer; shuffle.
    static func buildOptions(for cloze: Cloze, in context: ModelContext) -> [AnswerOption] {
        let correct = AnswerOption(
            surface: cloze.surfaceForm,
            reading: cloze.reading,
            isCorrect: true
        )

        let descriptor = FetchDescriptor<Cloze>()
        let pool = (try? context.fetch(descriptor)) ?? []

        // Dedupe by lemma so we never show two options for the same word, drop
        // the target lemma itself and any empty surfaces. For each candidate
        // lemma, pick a random surface form from its sentence instances.
        var byLemma: [String: [Cloze]] = [:]
        for c in pool where c.lemma != cloze.lemma && !c.surfaceForm.isEmpty {
            byLemma[c.lemma, default: []].append(c)
        }
        let candidates: [Cloze] = byLemma.values.compactMap { $0.randomElement() }

        let targetLen = cloze.surfaceForm.count
        let posMatched = candidates.filter { $0.partOfSpeech == cloze.partOfSpeech }
        let posAndLength = posMatched.filter { abs($0.surfaceForm.count - targetLen) <= 1 }

        var picked = pickUpTo3(from: posAndLength)
        if picked.count < 3 {
            picked = backfill(picked, with: posMatched)
        }
        if picked.count < 3 {
            picked = backfill(picked, with: candidates)
        }

        let distractors = picked.prefix(3).map {
            AnswerOption(surface: $0.surfaceForm, reading: $0.reading, isCorrect: false)
        }
        var options = [correct] + distractors
        options.shuffle()
        return options
    }

    private static func pickUpTo3(from list: [Cloze]) -> [Cloze] {
        Array(list.shuffled().prefix(3))
    }

    private static func backfill(_ existing: [Cloze], with pool: [Cloze]) -> [Cloze] {
        guard existing.count < 3 else { return existing }
        let existingIDs = Set(existing.map(\.id))
        let extras = pool.filter { !existingIDs.contains($0.id) }.shuffled()
        let needed = 3 - existing.count
        return existing + extras.prefix(needed)
    }
}
