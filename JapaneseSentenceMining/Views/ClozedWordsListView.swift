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
    @Environment(LocalizationStore.self) private var loc

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
        .navigationTitle(loc.t("clozedWords.title", String(cards.count)))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Picker(loc.t("clozedWords.sort"), selection: $sort) {
                    ForEach(SortMode.allCases) { mode in
                        Text(label(for: mode)).tag(mode)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .overlay {
            if cards.isEmpty {
                ContentUnavailableView(
                    loc.t("clozedWords.empty.title"),
                    systemImage: "rectangle.stack",
                    description: Text(loc.t("clozedWords.empty.body"))
                )
            }
        }
    }

    private func label(for mode: SortMode) -> String {
        switch mode {
        case .firstClozed: return loc.t("clozedWords.sort.recentlyAdded")
        case .dueSoonest: return loc.t("clozedWords.sort.dueSoonest")
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
                    Text(loc.t("clozedWords.known"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(loc.t("clozedWords.dueIn", DueDescription.string(from: card.nextReviewAt)))
                .font(.footnote)
                .foregroundStyle(card.nextReviewAt <= .now ? .orange : .secondary)
            Text(card.clozes.count == 1
                 ? loc.t("clozedWords.stats.singular", String(total.correct), String(total.total), String(card.clozes.count))
                 : loc.t("clozedWords.stats.plural", String(total.correct), String(total.total), String(card.clozes.count)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
