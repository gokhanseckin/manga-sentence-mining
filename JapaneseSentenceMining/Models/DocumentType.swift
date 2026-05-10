import Foundation

enum DocumentType: String, Codable, CaseIterable, Sendable {
    case manga
    case print
    case unknown

    var localizationKey: String {
        switch self {
        case .manga: "documentType.manga"
        case .print: "documentType.print"
        case .unknown: "documentType.unknown"
        }
    }
}
