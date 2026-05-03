import Foundation
import SwiftData

@Model
final class CapturedPage {
    @Attribute(.unique) var id: UUID
    var capturedAt: Date
    var photoRelativePath: String

    init(id: UUID = UUID(), capturedAt: Date = .now, photoRelativePath: String) {
        self.id = id
        self.capturedAt = capturedAt
        self.photoRelativePath = photoRelativePath
    }
}
