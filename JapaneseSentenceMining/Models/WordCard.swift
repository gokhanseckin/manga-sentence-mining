import Foundation
import SwiftData

@Model
final class WordCard {
    #Index<WordCard>([\.nextReviewAt], [\.isKnown], [\.lemma])

    var id: UUID = UUID()
    var lemma: String = ""
    var representativeReading: String = ""
    var representativePOS: String = ""
    var ebisuAlpha: Double = 3.0
    var ebisuBeta: Double = 3.0
    var ebisuTHours: Double = 24.0
    var nextReviewAt: Date = Date.distantPast
    var lastReviewedAt: Date?
    var isKnown: Bool = false
    var firstClozedAt: Date = Date.now

    /// ISO 639-1 of the translation target at card creation. Snapshots stay
    /// in their original language even if the user later switches.
    var language: String = "en"

    /// Last edit timestamp. CloudKit handles per-field LWW automatically;
    /// this field is for UI ("edited 2d ago") and migration tooling.
    var modifiedAt: Date = Date.now

    /// JSON-encoded `[SourceSnapshot]`. Denormalized so iCloud sync surfaces
    /// review context on devices that don't have the source Page locally.
    @Attribute(.externalStorage) var sourceSnapshotsBlob: Data = Data()

    @Relationship(deleteRule: .nullify, inverse: \Cloze.wordCard)
    var clozes: [Cloze] = []

    @Relationship(deleteRule: .cascade, inverse: \ReviewEvent.wordCard)
    var reviewEvents: [ReviewEvent] = []

    init(
        id: UUID = UUID(),
        lemma: String,
        representativeReading: String,
        representativePOS: String,
        ebisuAlpha: Double,
        ebisuBeta: Double,
        ebisuTHours: Double,
        nextReviewAt: Date,
        lastReviewedAt: Date? = nil,
        isKnown: Bool = false,
        firstClozedAt: Date = .now,
        language: String = "en",
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.lemma = lemma
        self.representativeReading = representativeReading
        self.representativePOS = representativePOS
        self.ebisuAlpha = ebisuAlpha
        self.ebisuBeta = ebisuBeta
        self.ebisuTHours = ebisuTHours
        self.nextReviewAt = nextReviewAt
        self.lastReviewedAt = lastReviewedAt
        self.isKnown = isKnown
        self.firstClozedAt = firstClozedAt
        self.language = language
        self.modifiedAt = modifiedAt
    }
}

extension WordCard {
    static let maxSnapshots = 5

    var sourceSnapshots: [SourceSnapshot] {
        get {
            guard !sourceSnapshotsBlob.isEmpty else { return [] }
            return (try? JSONDecoder().decode([SourceSnapshot].self, from: sourceSnapshotsBlob)) ?? []
        }
        set {
            let trimmed = Array(newValue.suffix(Self.maxSnapshots))
            sourceSnapshotsBlob = (try? JSONEncoder().encode(trimmed)) ?? Data()
        }
    }

    func addSnapshot(_ snapshot: SourceSnapshot) {
        var current = sourceSnapshots
        current.removeAll { $0.sentenceText == snapshot.sentenceText && $0.pageId == snapshot.pageId }
        current.append(snapshot)
        sourceSnapshots = current
        modifiedAt = .now
    }
}
