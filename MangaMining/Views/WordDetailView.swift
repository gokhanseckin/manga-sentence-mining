import SwiftData
import SwiftUI

struct WordDetailView: View {
    @Bindable var card: WordCard
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings
    @State private var showDrillReview = false
    @State private var showDeleteConfirm = false

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
                LabeledContent("Part of speech", value: card.representativePOS)
                LabeledContent("Due", value: DueDescription.string(from: card.nextReviewAt))
                LabeledContent("Sentences", value: "\(activeClozes.count) active · \(excludedClozes.count) excluded")
                LabeledContent("Aggregate", value: "\(aggregate.correct)/\(aggregate.total) correct")
                LabeledContent("First clozed", value: card.firstClozedAt.formatted(date: .abbreviated, time: .omitted))
            }

            Section {
                Toggle("Mark as known", isOn: $card.isKnown)
                    .onChange(of: card.isKnown) { _, _ in try? modelContext.save() }
                Button {
                    showDrillReview = true
                } label: {
                    Label("Drill this word", systemImage: "play.circle.fill")
                }
                .disabled(activeClozes.isEmpty || card.isKnown)
            }

            Section("Sentences") {
                if activeClozes.isEmpty && excludedClozes.isEmpty {
                    Text("No sentences linked.")
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
                    Label("Delete cloze", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .confirmationDialog(
            "Delete this clozed word?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteCard()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes \(card.lemma) from clozed words and clears its review history. The sentences themselves stay.")
        }
        .navigationTitle(card.lemma)
        .navigationBarTitleDisplayMode(.inline)
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
                    highlightedSentence(cloze)
                        .font(.body)
                        .foregroundStyle(excluded ? AnyShapeStyle(HierarchicalShapeStyle.tertiary) : AnyShapeStyle(HierarchicalShapeStyle.primary))
                }
                .buttonStyle(.plain)
            } else {
                highlightedSentence(cloze)
                    .font(.body)
                    .foregroundStyle(excluded ? AnyShapeStyle(HierarchicalShapeStyle.tertiary) : AnyShapeStyle(HierarchicalShapeStyle.primary))
            }
            HStack {
                Text("\(cloze.correctCount)/\(attempts) correct")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("Ask this sentence", isOn: Binding(
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
