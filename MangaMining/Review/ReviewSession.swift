import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class ReviewSession {
    enum Phase: Equatable {
        case question
        case feedback(selectedIndex: Int, isCorrect: Bool)
    }

    private let modelContext: ModelContext
    private let settings: SettingsStore
    private var queue: [WordCard]
    private var firstAttemptLogged: Set<UUID> = []
    private(set) var totalUnique: Int

    var currentOptions: [AnswerOption] = []
    var currentCloze: Cloze?
    var phase: Phase = .question
    var furiganaShown: Bool = false
    private(set) var questionStartedAt: Date = .now
    private(set) var sentenceTokensCache: [JapaneseToken] = []

    var currentCard: WordCard? { queue.first }
    var remainingUniqueCount: Int { queue.count }
    var isComplete: Bool { queue.isEmpty }

    init(modelContext: ModelContext, settings: SettingsStore) {
        self.modelContext = modelContext
        self.settings = settings
        let now = Date.now
        var descriptor = FetchDescriptor<WordCard>(
            predicate: #Predicate { !$0.isKnown && $0.nextReviewAt <= now },
            sortBy: [SortDescriptor(\.nextReviewAt, order: .forward)]
        )
        descriptor.fetchLimit = max(settings.sessionSize, 1)
        let due = (try? modelContext.fetch(descriptor)) ?? []
        let usable = due.filter { card in
            card.clozes.contains { !$0.excludedFromReview }
        }
        self.queue = usable
        self.totalUnique = usable.count
        loadCurrent()
    }

    /// Drills a specific set of word cards on demand — bypasses the due filter.
    /// Used by the "Quiz these clozes" / per-word drill buttons so freshly
    /// picked clozes can be exercised immediately.
    init(modelContext: ModelContext, settings: SettingsStore, cards: [WordCard]) {
        self.modelContext = modelContext
        self.settings = settings
        let active = cards.filter { card in
            !card.isKnown && card.clozes.contains { !$0.excludedFromReview }
        }
        self.queue = active
        self.totalUnique = active.count
        loadCurrent()
    }

    func submit(answerIndex: Int) {
        guard case .question = phase else { return }
        guard let card = currentCard,
              let cloze = currentCloze,
              currentOptions.indices.contains(answerIndex) else { return }
        let isCorrect = currentOptions[answerIndex].isCorrect
        let isFirstAttempt = !firstAttemptLogged.contains(card.id)
        if isFirstAttempt {
            firstAttemptLogged.insert(card.id)
            let elapsedMs = max(Int(Date.now.timeIntervalSince(questionStartedAt) * 1000), 0)
            SchedulingService.recordFirstAttempt(
                wordCard: card,
                cloze: cloze,
                wasCorrect: isCorrect,
                responseTimeMs: elapsedMs,
                in: modelContext
            )
            try? modelContext.save()
        }
        phase = .feedback(selectedIndex: answerIndex, isCorrect: isCorrect)
    }

    func advance() {
        guard case .feedback(_, let isCorrect) = phase else { return }
        guard !queue.isEmpty else { return }
        let popped = queue.removeFirst()
        if !isCorrect {
            queue.append(popped)
        }
        loadCurrent()
    }

    func setKnown(_ known: Bool) {
        guard let card = currentCard else { return }
        card.isKnown = known
        try? modelContext.save()
        if known {
            queue.removeFirst()
            phase = .question
            loadCurrent()
        }
    }

    private func loadCurrent() {
        guard let card = currentCard else {
            currentOptions = []
            currentCloze = nil
            sentenceTokensCache = []
            phase = .question
            return
        }
        // Random non-excluded sentence instance.
        let pool = card.clozes.filter { !$0.excludedFromReview }
        guard let cloze = pool.randomElement() else {
            // All sentences excluded for this card — drop and try the next.
            queue.removeFirst()
            loadCurrent()
            return
        }
        currentCloze = cloze
        currentOptions = AnswerOptionsBuilder.buildOptions(for: cloze, in: modelContext)
        questionStartedAt = .now
        furiganaShown = false
        phase = .question
        sentenceTokensCache = []
        let text = cloze.sentence?.text ?? ""
        let cardID = card.id
        Task { [weak self] in
            let tokens = (try? await JapaneseTokenizer.shared.tokenize(text)) ?? []
            await MainActor.run {
                guard let self else { return }
                if self.currentCard?.id == cardID {
                    self.sentenceTokensCache = tokens
                }
            }
        }
    }
}
