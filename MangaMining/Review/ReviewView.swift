import SwiftData
import SwiftUI

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings

    let drillQuestions: [ClozeQuestion]?

    @State private var session: ReviewSession?

    init(drillQuestions: [ClozeQuestion]? = nil) {
        self.drillQuestions = drillQuestions
    }

    var body: some View {
        NavigationStack {
            Group {
                if let session, !session.isComplete, let question = session.currentQuestion {
                    QuestionScreen(session: session, question: question)
                } else if session?.totalUnique == 0 {
                    AllCaughtUp()
                } else {
                    SessionDone {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            if session == nil {
                if let drillQuestions {
                    session = ReviewSession(modelContext: modelContext, settings: settings, questions: drillQuestions)
                } else {
                    session = ReviewSession(modelContext: modelContext, settings: settings)
                }
            }
        }
    }
}

private struct QuestionScreen: View {
    @Bindable var session: ReviewSession
    let question: ClozeQuestion

    var body: some View {
        VStack(spacing: 20) {
            counterRow

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SentenceDisplay(
                        question: question,
                        tokens: session.sentenceTokensCache,
                        furiganaShown: session.furiganaShown,
                        feedback: feedbackState
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let translation = question.cloze?.sentence?.translationTr,
                       case .feedback = session.phase {
                        Text(translation)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    optionsList
                }
                .padding(.horizontal)
            }

            actionsRow
                .padding(.horizontal)
                .padding(.bottom)
        }
    }

    private var feedbackState: SentenceDisplay.Feedback {
        switch session.phase {
        case .question: return .blanked
        case .feedback: return .revealed
        }
    }

    private var counterRow: some View {
        HStack {
            Text("\(session.remainingUniqueCount) left")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Toggle(isOn: Binding(
                get: { question.isKnown },
                set: { session.setKnown($0) }
            )) {
                Label("Known", systemImage: "checkmark.seal")
                    .labelStyle(.titleAndIcon)
            }
            .toggleStyle(.button)
            .controlSize(.small)
            Button {
                session.furiganaShown.toggle()
            } label: {
                Label(
                    session.furiganaShown ? "Hide furigana" : "Show furigana",
                    systemImage: "character.book.closed.ja"
                )
                .labelStyle(.iconOnly)
                .imageScale(.large)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var optionsList: some View {
        VStack(spacing: 10) {
            ForEach(Array(session.currentOptions.enumerated()), id: \.element.id) { idx, option in
                OptionButton(
                    option: option,
                    state: state(for: idx, option: option),
                    furiganaShown: session.furiganaShown
                ) {
                    session.submit(answerIndex: idx)
                }
            }
        }
    }

    private func state(for idx: Int, option: AnswerOption) -> OptionButton.OptionState {
        switch session.phase {
        case .question:
            return .idle
        case .feedback(let selectedIndex, _):
            if option.isCorrect { return .correct }
            if idx == selectedIndex { return .wrong }
            return .dimmed
        }
    }

    @ViewBuilder
    private var actionsRow: some View {
        switch session.phase {
        case .question:
            EmptyView()
        case .feedback:
            Button {
                session.advance()
            } label: {
                Text("Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

private struct SentenceDisplay: View {
    enum Feedback { case blanked, revealed }

    let question: ClozeQuestion
    let tokens: [JapaneseToken]
    let furiganaShown: Bool
    let feedback: Feedback

    var body: some View {
        FlowLayout(spacing: 4, lineSpacing: 8) {
            ForEach(Array(renderable.enumerated()), id: \.offset) { _, item in
                tokenView(item)
            }
        }
    }

    private struct Renderable {
        let surface: String
        let reading: String
        let isCloze: Bool
    }

    private var renderable: [Renderable] {
        guard let cloze = question.cloze else { return [] }
        guard !tokens.isEmpty else {
            // Fallback: show sentence as a single chunk with the cloze blanked.
            let text = cloze.sentence?.text ?? ""
            switch feedback {
            case .blanked:
                let blank = String(repeating: "◯", count: max(cloze.surfaceForm.count, 1))
                let masked = text.replacingOccurrences(of: cloze.surfaceForm, with: blank, options: [], range: nil)
                return [Renderable(surface: masked, reading: "", isCloze: false)]
            case .revealed:
                return [Renderable(surface: text, reading: "", isCloze: false)]
            }
        }
        return tokens.map { token in
            let isCloze = token.surface == cloze.surfaceForm
                && containsRange(token: token, cloze: cloze)
            let display: String
            if isCloze, feedback == .blanked {
                display = String(repeating: "◯", count: max(token.surface.count, 1))
            } else {
                display = token.surface
            }
            return Renderable(surface: display, reading: token.reading, isCloze: isCloze)
        }
    }

    private func containsRange(token: JapaneseToken, cloze: Cloze) -> Bool {
        let text = cloze.sentence?.text ?? ""
        let start = text.distance(from: text.startIndex, to: token.range.lowerBound)
        let end = text.distance(from: text.startIndex, to: token.range.upperBound)
        return start == cloze.startOffset && end == cloze.endOffset
    }

    @ViewBuilder
    private func tokenView(_ item: Renderable) -> some View {
        let showRuby = furiganaShown
            && !item.reading.isEmpty
            && item.surface.containsKanji
            && !item.isCloze
        VStack(spacing: 1) {
            if showRuby {
                Text(item.reading)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(item.surface)
                .font(.title2)
                .foregroundStyle(item.isCloze ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(HierarchicalShapeStyle.primary))
        }
    }
}

private struct OptionButton: View {
    enum OptionState { case idle, correct, wrong, dimmed }

    let option: AnswerOption
    let state: OptionState
    let furiganaShown: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(spacing: 1) {
                    if furiganaShown, !option.reading.isEmpty, option.surface.containsKanji {
                        Text(option.reading)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(option.surface)
                        .font(.title3)
                }
                Spacer()
                trailing
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(state != .idle)
    }

    private var background: some ShapeStyle {
        switch state {
        case .idle: return AnyShapeStyle(Color(.secondarySystemBackground))
        case .correct: return AnyShapeStyle(Color.green.opacity(0.25))
        case .wrong: return AnyShapeStyle(Color.red.opacity(0.25))
        case .dimmed: return AnyShapeStyle(Color(.secondarySystemBackground).opacity(0.5))
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch state {
        case .correct: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .wrong: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        default: EmptyView()
        }
    }
}

private struct AllCaughtUp: View {
    var body: some View {
        ContentUnavailableView(
            "All caught up",
            systemImage: "checkmark.seal",
            description: Text("Mine more sentences to grow the review pool.")
        )
    }
}

private struct SessionDone: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(.tint)
            Text("Session complete").font(.title3.bold())
            Button("Done", action: onClose).buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

extension String {
    var containsKanji: Bool {
        unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
                || (0x3400...0x4DBF).contains(Int(scalar.value))
                || (0x20000...0x2A6DF).contains(Int(scalar.value))
        }
    }
}
