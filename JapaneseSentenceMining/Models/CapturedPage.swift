import Foundation
import SwiftData

@Model
final class CapturedPage {
    var id: UUID = UUID()
    var capturedAt: Date = Date.now
    var modifiedAt: Date = Date.now
    var photoRelativePath: String = ""

    /// Auto-detected document type from Gemini OCR. Drives layout-specific
    /// rendering (panels for manga, paragraphs for print).
    var documentTypeRaw: String = DocumentType.unknown.rawValue
    var documentType: DocumentType {
        get { DocumentType(rawValue: documentTypeRaw) ?? .unknown }
        set { documentTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        capturedAt: Date = .now,
        modifiedAt: Date = .now,
        photoRelativePath: String,
        documentType: DocumentType = .unknown
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.modifiedAt = modifiedAt
        self.photoRelativePath = photoRelativePath
        self.documentTypeRaw = documentType.rawValue
    }
}
