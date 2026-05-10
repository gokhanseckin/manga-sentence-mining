import SwiftData
import SwiftUI

struct WordDetailView: View {
    @Bindable var card: WordCard
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings
    @Environment(LocalizationStore.self) private var loc
    @State private var showDrillReview = false
    @State private var showDeleteConfirm = false
    @State private var showFurigana = false

    var body: some View {
        Form {
            Section {
                HStack(alignment: .firstTextBaseline) {
                    Text(card.lemma).font(.title.bold())
                    if !card.representativeReading.isEmpty, card.representativeReading != card.lemma {
                        Text("・\(card.representativeReading)")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent(loc.t("wordDetail.partOfSpeech"), value: card.representativePOS)
                LabeledContent(loc.t("wordDetail.due"), value: DueDescription.string(from: card.nextReviewAt))
                LabeledContent(loc.t("wordDetail.sentencesCount"), value: loc.t("wordDetail.sentencesValue", String(activeClozes.count), String(excludedClozes.count)))
                LabeledContent(loc.t("wordDetail.aggregate"), value: loc.t("wordDetail.aggregateValue", String(aggregate.correct), String(aggregate.total)))
                LabeledContent(loc.t("wordDetail.firstClozed"), value: card.firstClozedAt.formatted(date: .abbreviated, time: .omitted))
            }

            Section {
                Toggle(loc.t("wordDetail.markKnown"), isOn: $card.isKnown)
                    .onChange(of: card.isKnown) { _, _ in try? modelContext.save() }
                Button {
                    showDrillReview = true
                } label: {
                    Label(loc.t("wordDetail.drill"), systemImage: "play.circle.fill")
                }
                .disabled(activeClozes.isEmpty || card.isKnown)
            }

            Section(loc.t("wordDetail.section.sentences")) {
                if activeClozes.isEmpty && excludedClozes.isEmpty {
                    Text(loc.t("wordDetail.noSentences"))
                        .foregroundStyle(.secondary)
                }
                ForEach(activeClozes) { cloze in
                    sentenceRow(cloze, excluded: false)
                }
                if !excludedClozes.isEmpty {
                    ForEach(excludedClozes) { cloze in
                        sentenceRow(cloze, excluded: true)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label(loc.t("wordDetail.delete"), systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .confirmationDialog(
            loc.t("wordDetail.deleteConfirm.title"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(loc.t("common.delete"), role: .destructive) {
                deleteCard()
            }
            Button(loc.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(loc.t("wordDetail.deleteConfirm.message", card.lemma))
        }
        .navigationTitle(card.lemma)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                FuriganaToggleButton(showFurigana: $showFurigana)
            }
        }
        .sheet(isPresented: $showDrillReview) {
            ReviewView(drillCards: [card])
        }
    }

    private var activeClozes: [Cloze] {
        card.clozes
            .filter { !$0.excludedFromReview }
            .sorted { ($0.sentence?.createdAt ?? .distantPast) > ($1.sentence?.createdAt ?? .distantPast) }
    }

    private var excludedClozes: [Cloze] {
        card.clozes
            .filter { $0.excludedFromReview }
            .sorted { ($0.sentence?.createdAt ?? .distantPast) > ($1.sentence?.createdAt ?? .distantPast) }
    }

    private func deleteCard() {
        // Delete the per-sentence Cloze rows so the word isn't re-clozed by
        // the auto-linker on the next ingest. Sentences themselves stay.
        for cloze in card.clozes {
            modelContext.delete(cloze)
        }
        modelContext.delete(card)
        try? modelContext.save()
        dismiss()
    }

    private var aggregate: (correct: Int, total: Int) {
        card.clozes.reduce(into: (correct: 0, total: 0)) { acc, c in
            acc.correct += c.correctCount
            acc.total += c.correctCount + c.incorrectCount
        }
    }

    @ViewBuilder
    private func sentenceRow(_ cloze: Cloze, excluded: Bool) -> some View {
        let attempts = cloze.correctCount + cloze.incorrectCount
        VStack(alignment: .leading, spacing: 6) {
            if let sentence = cloze.sentence {
                NavigationLink {
                    SentenceDetailView(sentence: sentence)
                } label: {
                    sentenceRowText(cloze, excluded: excluded)
                }
                .buttonStyle(.plain)
            } else {
                sentenceRowText(cloze, excluded: excluded)
            }
            HStack {
                Text(loc.t("wordDetail.attempts", String(cloze.correctCount), String(attempts)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle(loc.t("wordDetail.askThisSentence"), isOn: Binding(
                    get: { !cloze.excludedFromReview },
                    set: { newValue in
                        cloze.excludedFromReview = !newValue
                        try? modelContext.save()
                    }
                ))
                .labelsHidden()
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func sentenceRowText(_ cloze: Cloze, excluded: Bool) -> some View {
        if showFurigana, let text = cloze.sentence?.text {
            // Furigana mode trades the cloze highlight for kana-over-kanji
            // so the user can read the sentence with readings.
            JapaneseText(text: text, showFurigana: .constant(true), font: .body)
                .foregroundStyle(excluded ? AnyShapeStyle(HierarchicalShapeStyle.tertiary) : AnyShapeStyle(HierarchicalShapeStyle.primary))
        } else {
            highlightedSentence(cloze)
                .font(.body)
                .foregroundStyle(excluded ? AnyShapeStyle(HierarchicalShapeStyle.tertiary) : AnyShapeStyle(HierarchicalShapeStyle.primary))
        }
    }

    private func highlightedSentence(_ cloze: Cloze) -> Text {
        let text = cloze.sentence?.text ?? ""
        guard cloze.startOffset >= 0,
              cloze.endOffset <= text.count,
              cloze.startOffset < cloze.endOffset else {
            return Text(text)
        }
        let start = text.index(text.startIndex, offsetBy: cloze.startOffset)
        let end = text.index(text.startIndex, offsetBy: cloze.endOffset)
        let before = String(text[text.startIndex..<start])
        let middle = String(text[start..<end])
        let after = String(text[end..<text.endIndex])
        return Text(before) + Text(middle).foregroundColor(.accentColor).bold() + Text(after)
    }
}
