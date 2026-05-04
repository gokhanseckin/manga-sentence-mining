import Foundation
import SwiftData

@MainActor
enum AnswerOptionsBuilder {
    /// Builds four shuffled answer options for the given cloze question.
    ///
    /// PR 5 implementation: random other clozes' surface forms, no POS or
    /// length filtering. PR 6 replaces this with the real distractor algorithm
    /// (POS-matched, length-similar, drawn from the user's mined-word pool).
    static func buildOptions(for cloze: Cloze, in context: ModelContext) -> [AnswerOption] {
        let correct = AnswerOption(
            surface: cloze.surfaceForm,
            reading: cloze.reading,
            isCorrect: true
        )
        let descriptor = FetchDescriptor<Cloze>()
        let pool = (try? context.fetch(descriptor)) ?? []
        let candidates = pool.filter { $0.lemma != cloze.lemma && !$0.surfaceForm.isEmpty }
        let distractors = candidates.shuffled().prefix(3).map {
            AnswerOption(surface: $0.surfaceForm, reading: $0.reading, isCorrect: false)
        }
        var options = [correct] + distractors
        options.shuffle()
        return options
    }
}
