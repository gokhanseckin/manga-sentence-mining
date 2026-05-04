import Foundation
import SwiftData

@Model
final class Sentence {
    @Attribute(.unique) var id: UUID
    var text: String
    var reading: String?
    var createdAt: Date
    var translationTr: String?
    var capturedPage: CapturedPage?

    init(
        id: UUID = UUID(),
        text: String,
        reading: String? = nil,
        createdAt: Date = .now,
        translationTr: String? = nil,
        capturedPage: CapturedPage? = nil
    ) {
        self.id = id
        self.text = text
        self.reading = reading
        self.createdAt = createdAt
        self.translationTr = translationTr
        self.capturedPage = capturedPage
    }
}
