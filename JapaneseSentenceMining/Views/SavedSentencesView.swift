import SwiftData
import SwiftUI

struct SavedSentencesView: View {
    @Query(sort: \Sentence.createdAt, order: .reverse) private var sentences: [Sentence]
    @Environment(LocalizationStore.self) private var loc

    var body: some View {
        Group {
            if sentences.isEmpty {
                ContentUnavailableView(
                    loc.t("savedSentences.empty.title"),
                    systemImage: "text.book.closed",
                    description: Text(loc.t("savedSentences.empty.body"))
                )
            } else {
                List {
                    ForEach(sentences) { sentence in
                        NavigationLink {
                            SentenceDetailView(sentence: sentence)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(sentence.text)
                                    .font(.body)
                                    .lineLimit(2)
                                if let tr = sentence.translation, !tr.isEmpty {
                                    Text(tr)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Text(sentence.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .navigationTitle(loc.t("savedSentences.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
