import Foundation
import SwiftData

@Model
final class ReviewEvent {
    #Index<ReviewEvent>([\.reviewedAt])

    @Attribute(.unique) var id: UUID
    // Legacy FK retained so existing rows can be migrated to wordCard/cloze on first
    // launch. New events leave this nil.
    var clozeQuestion: ClozeQuestion?
    var wordCard: WordCard?
    var cloze: Cloze?
    var reviewedAt: Date
    var wasCorrect: Bool
    var responseTimeMs: Int
    var ebisuAlphaBefore: Double
    var ebisuBetaBefore: Double
    var ebisuTHoursBefore: Double
    var ebisuAlphaAfter: Double
    var ebisuBetaAfter: Double
    var ebisuTHoursAfter: Double

    init(
        id: UUID = UUID(),
        clozeQuestion: ClozeQuestion? = nil,
        wordCard: WordCard? = nil,
        cloze: Cloze? = nil,
        reviewedAt: Date = .now,
        wasCorrect: Bool,
        responseTimeMs: Int,
        ebisuAlphaBefore: Double,
        ebisuBetaBefore: Double,
        ebisuTHoursBefore: Double,
        ebisuAlphaAfter: Double,
        ebisuBetaAfter: Double,
        ebisuTHoursAfter: Double
    ) {
        self.id = id
        self.clozeQuestion = clozeQuestion
        self.wordCard = wordCard
        self.cloze = cloze
        self.reviewedAt = reviewedAt
        self.wasCorrect = wasCorrect
        self.responseTimeMs = responseTimeMs
        self.ebisuAlphaBefore = ebisuAlphaBefore
        self.ebisuBetaBefore = ebisuBetaBefore
        self.ebisuTHoursBefore = ebisuTHoursBefore
        self.ebisuAlphaAfter = ebisuAlphaAfter
        self.ebisuBetaAfter = ebisuBetaAfter
        self.ebisuTHoursAfter = ebisuTHoursAfter
    }
}
