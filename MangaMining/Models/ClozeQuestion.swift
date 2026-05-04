import Foundation
import SwiftData

@Model
final class ClozeQuestion {
    #Index<ClozeQuestion>([\.nextReviewAt], [\.isKnown])

    @Attribute(.unique) var id: UUID
    var cloze: Cloze?
    var ebisuAlpha: Double
    var ebisuBeta: Double
    var ebisuTHours: Double
    var nextReviewAt: Date
    var lastReviewedAt: Date?
    var isKnown: Bool

    @Relationship(deleteRule: .cascade, inverse: \ReviewEvent.clozeQuestion)
    var reviewEvents: [ReviewEvent] = []

    init(
        id: UUID = UUID(),
        cloze: Cloze? = nil,
        ebisuAlpha: Double,
        ebisuBeta: Double,
        ebisuTHours: Double,
        nextReviewAt: Date,
        lastReviewedAt: Date? = nil,
        isKnown: Bool = false
    ) {
        self.id = id
        self.cloze = cloze
        self.ebisuAlpha = ebisuAlpha
        self.ebisuBeta = ebisuBeta
        self.ebisuTHours = ebisuTHours
        self.nextReviewAt = nextReviewAt
        self.lastReviewedAt = lastReviewedAt
        self.isKnown = isKnown
    }
}
