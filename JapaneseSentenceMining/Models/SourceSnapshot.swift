import Foundation

/// A denormalized copy of a source sentence at the moment it was linked to a
/// WordCard. Stored on the card so review context survives iCloud sync onto
/// a device that doesn't have the originating Page/Sentence locally.
struct SourceSnapshot: Codable, Hashable, Sendable {
    var sentenceText: String
    var reading: String
    var translation: String
    var translationLanguage: String
    var pageId: UUID?
    var capturedAt: Date

    init(
        sentenceText: String,
        reading: String,
        translation: String,
        translationLanguage: String,
        pageId: UUID? = nil,
        capturedAt: Date = .now
    ) {
        self.sentenceText = sentenceText
        self.reading = reading
        self.translation = translation
        self.translationLanguage = translationLanguage
        self.pageId = pageId
        self.capturedAt = capturedAt
    }
}
