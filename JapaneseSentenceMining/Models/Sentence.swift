import Foundation
import SwiftData

@Model
final class Sentence {
    #Index<Sentence>([\.createdAt])

    var id: UUID = UUID()
    var text: String = ""
    var reading: String?
    var createdAt: Date = Date.now
    var modifiedAt: Date = Date.now

    /// Translation in the user's selected language at the time of capture.
    var translation: String?

    /// ISO 639-1 of the `translation` field.
    var translationLanguage: String = "en"

    /// `manga` or `print`. Set from Gemini's auto-detection.
    var documentTypeRaw: String = DocumentType.unknown.rawValue
    var documentType: DocumentType {
        get { DocumentType(rawValue: documentTypeRaw) ?? .unknown }
        set { documentTypeRaw = newValue.rawValue }
    }

    var capturedPage: CapturedPage?

    @Relationship(deleteRule: .cascade, inverse: \Cloze.sentence)
    var clozesOptional: [Cloze]? = []

    var clozes: [Cloze] {
        get { clozesOptional ?? [] }
        set { clozesOptional = newValue }
    }

    var hasClozes: Bool { !clozes.isEmpty }

    init(
        id: UUID = UUID(),
        text: String,
        reading: String? = nil,
        createdAt: Date = .now,
        modifiedAt: Date = .now,
        translation: String? = nil,
        translationLanguage: String = "en",
        documentType: DocumentType = .unknown,
        capturedPage: CapturedPage? = nil
    ) {
        self.id = id
        self.text = text
        self.reading = reading
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.translation = translation
        self.translationLanguage = translationLanguage
        self.documentTypeRaw = documentType.rawValue
        self.capturedPage = capturedPage
    }
}
