import Foundation
import SwiftData

@Model
final class Cloze {
    @Attribute(.unique) var id: UUID
    var sentence: Sentence?
    var startOffset: Int
    var endOffset: Int
    var surfaceForm: String
    var lemma: String
    var reading: String
    var partOfSpeech: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ClozeQuestion.cloze)
    var questions: [ClozeQuestion] = []

    init(
        id: UUID = UUID(),
        sentence: Sentence? = nil,
        startOffset: Int,
        endOffset: Int,
        surfaceForm: String,
        lemma: String,
        reading: String,
        partOfSpeech: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.sentence = sentence
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.surfaceForm = surfaceForm
        self.lemma = lemma
        self.reading = reading
        self.partOfSpeech = partOfSpeech
        self.createdAt = createdAt
    }
}
