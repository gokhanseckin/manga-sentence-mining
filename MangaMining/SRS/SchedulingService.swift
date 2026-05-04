import Foundation
import SwiftData

@MainActor
enum SchedulingService {
    /// Creates the initial `ClozeQuestion` for a freshly picked `Cloze`. Uses
    /// the Ebisu prior currently configured in `SettingsStore` and materializes
    /// `nextReviewAt = createdAt + tHours` so the question enters the due pool
    /// after one full horizon.
    @discardableResult
    static func createInitialQuestion(
        for cloze: Cloze,
        in context: ModelContext,
        settings: SettingsStore
    ) -> ClozeQuestion {
        let model = EbisuModel(
            alpha: settings.ebisuDefaultAlpha,
            beta: settings.ebisuDefaultBeta,
            tHours: settings.ebisuDefaultTHours
        )
        let now = Date.now
        let question = ClozeQuestion(
            cloze: cloze,
            ebisuAlpha: model.alpha,
            ebisuBeta: model.beta,
            ebisuTHours: model.tHours,
            nextReviewAt: now.addingTimeInterval(model.tHours * 3600),
            lastReviewedAt: nil,
            isKnown: false
        )
        context.insert(question)
        return question
    }

    /// Records a first-attempt answer: applies the Ebisu posterior update,
    /// re-materializes `nextReviewAt` from `modelToPercentileDecay(0.5)`,
    /// writes both back to the `ClozeQuestion`, and appends a `ReviewEvent`.
    @discardableResult
    static func recordFirstAttempt(
        question: ClozeQuestion,
        wasCorrect: Bool,
        responseTimeMs: Int,
        in context: ModelContext
    ) -> ReviewEvent {
        let now = Date.now
        let elapsedHours: Double
        if let last = question.lastReviewedAt {
            elapsedHours = max(now.timeIntervalSince(last) / 3600, 1e-3)
        } else {
            // Never-reviewed question — anchor to the configured horizon so the
            // first update isn't degenerate.
            elapsedHours = max(question.ebisuTHours, 1e-3)
        }

        let before = EbisuModel(
            alpha: question.ebisuAlpha,
            beta: question.ebisuBeta,
            tHours: question.ebisuTHours
        )
        let after = Ebisu.updateRecall(model: before, wasCorrect: wasCorrect, elapsedHours: elapsedHours)
        let nextDecayHours = Ebisu.modelToPercentileDecay(model: after, percentile: 0.5)

        question.ebisuAlpha = after.alpha
        question.ebisuBeta = after.beta
        question.ebisuTHours = after.tHours
        question.lastReviewedAt = now
        question.nextReviewAt = now.addingTimeInterval(nextDecayHours * 3600)

        let event = ReviewEvent(
            clozeQuestion: question,
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
