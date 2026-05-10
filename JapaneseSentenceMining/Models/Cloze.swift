import Foundation
import SwiftData

@Model
final class Cloze {
    var id: UUID = UUID()
    var sentence: Sentence?
    var wordCard: WordCard?
    var startOffset: Int = 0
    var endOffset: Int = 0
    var surfaceForm: String = ""
    var lemma: String = ""
    var reading: String = ""
    var partOfSpeech: String = ""
    var createdAt: Date = Date.now
    var modifiedAt: Date = Date.now
    var excludedFromReview: Bool = false
    var correctCount: Int = 0
    var incorrectCount: Int = 0

    init(
        id: UUID = UUID(),
        sentence: Sentence? = nil,
        wordCard: WordCard? = nil,
        startOffset: Int,
        endOffset: Int,
        surfaceForm: String,
        lemma: String,
        reading: String,
        partOfSpeech: String,
        createdAt: Date = .now,
        modifiedAt: Date = .now,
        excludedFromReview: Bool = false,
        correctCount: Int = 0,
        incorrectCount: Int = 0
    ) {
        self.id = id
        self.sentence = sentence
        self.wordCard = wordCard
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.surfaceForm = surfaceForm
        self.lemma = lemma
        self.reading = reading
        self.partOfSpeech = partOfSpeech
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.excludedFromReview = excludedFromReview
        self.correctCount = correctCount
        self.incorrectCount = incorrectCount
    }
}
