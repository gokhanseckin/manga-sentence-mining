import Foundation

struct AnswerOption: Identifiable, Sendable, Equatable {
    let id: UUID
    let surface: String
    let reading: String
    let isCorrect: Bool

    init(id: UUID = UUID(), surface: String, reading: String, isCorrect: Bool) {
        self.id = id
        self.surface = surface
        self.reading = reading
        self.isCorrect = isCorrect
    }
}
