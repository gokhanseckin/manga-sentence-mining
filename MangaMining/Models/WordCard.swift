import Foundation
import SwiftData

@Model
final class WordCard {
    #Index<WordCard>([\.nextReviewAt], [\.isKnown], [\.lemma])

    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var lemma: String
    var representativeReading: String
    var representativePOS: String
    var ebisuAlpha: Double
    var ebisuBeta: Double
    var ebisuTHours: Double
    var nextReviewAt: Date
    var lastReviewedAt: Date?
    var isKnown: Bool
    var firstClozedAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Cloze.wordCard)
    var clozes: [Cloze] = []

    @Relationship(deleteRule: .cascade, inverse: \ReviewEvent.wordCard)
    var reviewEvents: [ReviewEvent] = []

    init(
        id: UUID = UUID(),
        lemma: String,
        representativeReading: String,
        representativePOS: String,
        ebisuAlpha: Double,
        ebisuBeta: Double,
        ebisuTHours: Double,
        nextReviewAt: Date,
        lastReviewedAt: Date? = nil,
        isKnown: Bool = false,
        firstClozedAt: Date = .now
    ) {
        self.id = id
        self.lemma = lemma
        self.representativeReading = representativeReading
        self.representativePOS = representativePOS
        self.ebisuAlpha = ebisuAlpha
        self.ebisuBeta = ebisuBeta
        self.ebisuTHours = ebisuTHours
        self.nextReviewAt = nextReviewAt
        self.lastReviewedAt = lastReviewedAt
        self.isKnown = isKnown
        self.firstClozedAt = firstClozedAt
    }
}
