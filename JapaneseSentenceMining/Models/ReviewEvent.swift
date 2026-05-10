import Foundation
import SwiftData

@Model
final class ReviewEvent {
    #Index<ReviewEvent>([\.reviewedAt])

    var id: UUID = UUID()
    var wordCard: WordCard?
    var cloze: Cloze?
    var reviewedAt: Date = Date.now
    var modifiedAt: Date = Date.now
    var wasCorrect: Bool = false
    var responseTimeMs: Int = 0
    var ebisuAlphaBefore: Double = 0
    var ebisuBetaBefore: Double = 0
    var ebisuTHoursBefore: Double = 0
    var ebisuAlphaAfter: Double = 0
    var ebisuBetaAfter: Double = 0
    var ebisuTHoursAfter: Double = 0

    init(
        id: UUID = UUID(),
        wordCard: WordCard? = nil,
        cloze: Cloze? = nil,
        reviewedAt: Date = .now,
        modifiedAt: Date = .now,
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
        self.wordCard = wordCard
        self.cloze = cloze
        self.reviewedAt = reviewedAt
        self.modifiedAt = modifiedAt
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
