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
    private var queue: [ClozeQuestion]
    private var firstAttemptLogged: Set<UUID> = []
    private(set) var totalUnique: Int

    var currentOptions: [AnswerOption] = []
    var phase: Phase = .question
    var furiganaShown: Bool = false
    private(set) var questionStartedAt: Date = .now
    private(set) var sentenceTokensCache: [JapaneseToken] = []

    var currentQuestion: ClozeQuestion? { queue.first }
    var remainingUniqueCount: Int { queue.count }
    var isComplete: Bool { queue.isEmpty }

    init(modelContext: ModelContext, settings: SettingsStore) {
        self.modelContext = modelContext
        self.settings = settings
        let now = Date.now
        var descriptor = FetchDescriptor<ClozeQuestion>(
            predicate: #Predicate { !$0.isKnown && $0.nextReviewAt <= now },
            sortBy: [SortDescriptor(\.nextReviewAt, order: .forward)]
        )
        descriptor.fetchLimit = max(settings.sessionSize, 1)
        let due = (try? modelContext.fetch(descriptor)) ?? []
        self.queue = due
        self.totalUnique = due.count
        loadCurrent()
    }

    /// Drills a specific set of cloze questions on demand — bypasses the due
    /// filter. Used by the "Quiz these clozes" button on sentence detail so
    /// freshly picked clozes can be exercised immediately without waiting for
    /// their initial 24h horizon to elapse.
    init(modelContext: ModelContext, settings: SettingsStore, questions: [ClozeQuestion]) {
        self.modelContext = modelContext
        self.settings = settings
        let active = questions.filter { !$0.isKnown }
        self.queue = active
        self.totalUnique = active.count
        loadCurrent()
    }

    func submit(answerIndex: Int) {
        guard case .question = phase else { return }
        guard let question = currentQuestion, currentOptions.indices.contains(answerIndex) else { return }
        let isCorrect = currentOptions[answerIndex].isCorrect
        let isFirstAttempt = !firstAttemptLogged.contains(question.id)
        if isFirstAttempt {
            firstAttemptLogged.insert(question.id)
            let elapsedMs = max(Int(Date.now.timeIntervalSince(questionStartedAt) * 1000), 0)
            SchedulingService.recordFirstAttempt(
                question: question,
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
        guard let question = currentQuestion else { return }
        question.isKnown = known
        try? modelContext.save()
        if known {
            // Drop from queue immediately and move on.
            queue.removeFirst()
            phase = .question
            loadCurrent()
        }
    }

    private func loadCurrent() {
        guard let question = currentQuestion, let cloze = question.cloze else {
            currentOptions = []
            sentenceTokensCache = []
            phase = .question
            return
        }
        currentOptions = AnswerOptionsBuilder.buildOptions(for: cloze, in: modelContext)
        questionStartedAt = .now
        furiganaShown = false
        phase = .question
        // Tokenize the sentence text so the furigana toggle can render ruby.
        sentenceTokensCache = []
        let text = cloze.sentence?.text ?? ""
        Task { [weak self] in
            let tokens = (try? await JapaneseTokenizer.shared.tokenize(text)) ?? []
            await MainActor.run {
                guard let self else { return }
                if self.currentQuestion?.id == question.id {
                    self.sentenceTokensCache = tokens
                }
            }
        }
    }
}
