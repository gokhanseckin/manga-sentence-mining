import Foundation
import SwiftData

@MainActor
enum LemmaMigration {
    private static let didRunKey = "lemma_migration_v1_done"

    /// One-shot migration from the legacy per-`Cloze` SRS model to the per-lemma
    /// `WordCard` model. Idempotent — guarded by a UserDefaults flag so it runs
    /// at most once per install. Safe to call on a fresh install: there are no
    /// `ClozeQuestion`s, the function exits immediately and the flag is set.
    static func runIfNeeded(_ context: ModelContext) {
        if UserDefaults.standard.bool(forKey: didRunKey) { return }

        let questions = (try? context.fetch(FetchDescriptor<ClozeQuestion>())) ?? []
        if questions.isEmpty {
            UserDefaults.standard.set(true, forKey: didRunKey)
            return
        }

        // Group by lemma. ClozeQuestions whose Cloze has been cascade-deleted
        // (cloze == nil) are unmigratable — skip them; their ReviewEvents will
        // be cleaned up below.
        var byLemma: [String: [ClozeQuestion]] = [:]
        for q in questions {
            guard let lemma = q.cloze?.lemma else { continue }
            byLemma[lemma, default: []].append(q)
        }

        // Cache existing WordCards (none on first migration but keep idempotent).
        let existing = (try? context.fetch(FetchDescriptor<WordCard>())) ?? []
        var cardByLemma: [String: WordCard] = [:]
        for c in existing { cardByLemma[c.lemma] = c }

        for (lemma, group) in byLemma {
            // Pick canonical: most-reviewed wins; tie-break on most-recent
            // lastReviewedAt; final tie-break on first-created.
            let canonical = group.max { a, b in
                let ac = a.reviewEvents.count, bc = b.reviewEvents.count
                if ac != bc { return ac < bc }
                let al = a.lastReviewedAt ?? .distantPast
                let bl = b.lastReviewedAt ?? .distantPast
                return al < bl
            }!

            let representativeCloze = canonical.cloze
            let card: WordCard
            if let existingCard = cardByLemma[lemma] {
                card = existingCard
            } else {
                card = WordCard(
                    lemma: lemma,
                    representativeReading: representativeCloze?.reading ?? "",
                    representativePOS: representativeCloze?.partOfSpeech ?? "",
                    ebisuAlpha: canonical.ebisuAlpha,
                    ebisuBeta: canonical.ebisuBeta,
                    ebisuTHours: canonical.ebisuTHours,
                    nextReviewAt: canonical.nextReviewAt,
                    lastReviewedAt: canonical.lastReviewedAt,
                    isKnown: group.allSatisfy { $0.isKnown },
                    firstClozedAt: group.compactMap { $0.cloze?.createdAt }.min() ?? .now
                )
                context.insert(card)
                cardByLemma[lemma] = card
            }

            // Attach all clozes in the group, repoint review events, recompute
            // per-cloze counts.
            for q in group {
                guard let cloze = q.cloze else { continue }
                cloze.wordCard = card
                cloze.excludedFromReview = false
                var c = 0, w = 0
                for ev in q.reviewEvents {
                    ev.wordCard = card
                    ev.cloze = cloze
                    ev.clozeQuestion = nil
                    if ev.wasCorrect { c += 1 } else { w += 1 }
                }
                cloze.correctCount = c
                cloze.incorrectCount = w
            }
        }

        // Delete legacy ClozeQuestion rows (their ReviewEvents were repointed
        // above; whatever remains was orphaned and is removed with the row).
        for q in questions {
            context.delete(q)
        }

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: didRunKey)
        } catch {
            print("LemmaMigration save failed: \(error)")
        }
    }
}
