import Foundation
import SwiftData

@MainActor
enum SchedulingService {
    /// Creates the initial `ClozeQuestion` for a freshly picked `Cloze`.
    ///
    /// PR 4 will replace these defaults with the user-tunable Ebisu prior from
    /// `SettingsStore` and route `nextReviewAt` through the real percentile-decay
    /// math. For PR 3 we want every new `Cloze` to have a question row so the
    /// quiz UI can find it.
    @discardableResult
    static func createInitialQuestion(for cloze: Cloze, in context: ModelContext) -> ClozeQuestion {
        let alpha = 3.0
        let beta = 3.0
        let tHours = 24.0
        let now = Date.now
        let question = ClozeQuestion(
            cloze: cloze,
            ebisuAlpha: alpha,
            ebisuBeta: beta,
            ebisuTHours: tHours,
            nextReviewAt: now.addingTimeInterval(tHours * 3600),
            lastReviewedAt: nil,
            isKnown: false
        )
        context.insert(question)
        return question
    }
}
