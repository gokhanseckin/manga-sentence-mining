import Foundation
import SwiftData

@Model
final class Sentence {
    @Attribute(.unique) var id: UUID
    var text: String
    var createdAt: Date
    var translationTr: String?
    var capturedPage: CapturedPage?

    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = .now,
        translationTr: String? = nil,
        capturedPage: CapturedPage? = nil
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.translationTr = translationTr
        self.capturedPage = capturedPage
    }
}
