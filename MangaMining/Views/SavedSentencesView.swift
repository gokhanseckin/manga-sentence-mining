import SwiftData
import SwiftUI

struct SavedSentencesView: View {
    @Query(sort: \Sentence.createdAt, order: .reverse) private var sentences: [Sentence]

    var body: some View {
        Group {
            if sentences.isEmpty {
                ContentUnavailableView(
                    "No sentences yet",
                    systemImage: "text.book.closed",
                    description: Text("Capture a manga page from the home screen.")
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
                                Text(sentence.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .navigationTitle("Saved sentences")
        .navigationBarTitleDisplayMode(.inline)
    }
}
