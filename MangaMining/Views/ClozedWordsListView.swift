import SwiftData
import SwiftUI

struct ClozedWordsListView: View {
    enum SortMode: String, CaseIterable, Identifiable {
        case firstClozed = "Recently added"
        case dueSoonest = "Due soonest"
        var id: String { rawValue }
    }

    @Query(sort: \WordCard.firstClozedAt, order: .reverse) private var cardsByAdded: [WordCard]
    @Query(sort: \WordCard.nextReviewAt, order: .forward) private var cardsByDue: [WordCard]
    @State private var sort: SortMode = .firstClozed

    private var cards: [WordCard] {
        switch sort {
        case .firstClozed: return cardsByAdded
        case .dueSoonest: return cardsByDue
        }
    }

    var body: some View {
        List {
            ForEach(cards) { card in
                NavigationLink {
                    WordDetailView(card: card)
                } label: {
                    row(for: card)
                }
            }
        }
        .navigationTitle("Clozed words (\(cards.count))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Picker("Sort", selection: $sort) {
                    ForEach(SortMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .overlay {
            if cards.isEmpty {
                ContentUnavailableView(
                    "No clozed words yet",
                    systemImage: "rectangle.stack",
                    description: Text("Pick clozes from a sentence to start tracking words.")
                )
            }
        }
    }

    @ViewBuilder
    private func row(for card: WordCard) -> some View {
        let total = card.clozes.reduce(into: (correct: 0, total: 0)) { acc, c in
            acc.correct += c.correctCount
            acc.total += c.correctCount + c.incorrectCount
        }
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.lemma)
                    .font(.title3)
                if !card.representativeReading.isEmpty, card.representativeReading != card.lemma {
                    Text("・\(card.representativeReading)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if card.isKnown {
                    Text("Known")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text("Will be due in \(DueDescription.string(from: card.nextReviewAt))")
                .font(.footnote)
                .foregroundStyle(card.nextReviewAt <= .now ? .orange : .secondary)
            Text("\(total.correct)/\(total.total) correct · \(card.clozes.count) sentence\(card.clozes.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
