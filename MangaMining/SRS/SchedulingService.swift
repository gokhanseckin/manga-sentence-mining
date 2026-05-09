import Foundation
import SwiftData

@MainActor
enum SchedulingService {
    /// Look up an existing `WordCard` by lemma, or create a fresh one with the
    /// configured Ebisu prior. The new card's `nextReviewAt` is materialized to
    /// `now + tHours` so it enters the due pool after one full horizon.
    @discardableResult
    static func getOrCreateWordCard(
        forLemma lemma: String,
        reading: String,
        partOfSpeech: String,
        in context: ModelContext,
        settings: SettingsStore
    ) -> WordCard {
        var descriptor = FetchDescriptor<WordCard>(
            predicate: #Predicate { $0.lemma == lemma }
        )
        descriptor.fetchLimit = 1
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let now = Date.now
        let card = WordCard(
            lemma: lemma,
            representativeReading: reading,
            representativePOS: partOfSpeech,
            ebisuAlpha: settings.ebisuDefaultAlpha,
            ebisuBeta: settings.ebisuDefaultBeta,
            ebisuTHours: settings.ebisuDefaultTHours,
            nextReviewAt: now.addingTimeInterval(settings.ebisuDefaultTHours * 3600),
            lastReviewedAt: nil,
            isKnown: false,
            firstClozedAt: now
        )
        context.insert(card)
        return card
    }

    /// Records a first-attempt answer against `wordCard`, applying the Ebisu
    /// posterior update on the card and re-materializing `nextReviewAt` from
    /// `modelToPercentileDecay(0.5)`. Per-sentence stats are bumped on `cloze`.
    @discardableResult
    static func recordFirstAttempt(
        wordCard: WordCard,
        cloze: Cloze,
        wasCorrect: Bool,
        responseTimeMs: Int,
        in context: ModelContext
    ) -> ReviewEvent {
        let now = Date.now
        let elapsedHours: Double
        if let last = wordCard.lastReviewedAt {
            elapsedHours = max(now.timeIntervalSince(last) / 3600, 1e-3)
        } else {
            elapsedHours = max(wordCard.ebisuTHours, 1e-3)
        }

        let before = EbisuModel(
            alpha: wordCard.ebisuAlpha,
            beta: wordCard.ebisuBeta,
            tHours: wordCard.ebisuTHours
        )
        let after = Ebisu.updateRecall(model: before, wasCorrect: wasCorrect, elapsedHours: elapsedHours)
        let nextDecayHours = Ebisu.modelToPercentileDecay(model: after, percentile: 0.5)

        wordCard.ebisuAlpha = after.alpha
        wordCard.ebisuBeta = after.beta
        wordCard.ebisuTHours = after.tHours
        wordCard.lastReviewedAt = now
        wordCard.nextReviewAt = now.addingTimeInterval(nextDecayHours * 3600)

        if wasCorrect {
            cloze.correctCount += 1
        } else {
            cloze.incorrectCount += 1
        }

        let event = ReviewEvent(
            wordCard: wordCard,
            cloze: cloze,
            reviewedAt: now,
            wasCorrect: wasCorrect,
            responseTimeMs: responseTimeMs,
            ebisuAlphaBefore: before.alpha,
            ebisuBetaBefore: before.beta,
            ebisuTHoursBefore: before.tHours,
            ebisuAlphaAfter: after.alpha,
            ebisuBetaAfter: after.beta,
            ebisuTHoursAfter: after.tHours
        )
        context.insert(event)
        return event
    }
}
