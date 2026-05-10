import SwiftData
import SwiftUI

struct SentenceDetailView: View {
    @Bindable var sentence: Sentence
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var draftText: String = ""
    @State private var draftReading: String = ""
    @State private var draftTranslation: String = ""
    @State private var showDeleteConfirm = false
    @State private var showClozePicker = false
    @State private var showDrillReview = false
    @State private var showFullImage = false
    @State private var showFurigana = false

    var body: some View {
        Form {
            Section("Original (日本語)") {
                if isEditing {
                    TextField("Original", text: $draftText, axis: .vertical)
                        .lineLimit(2...10)
                } else {
                    JapaneseText(text: sentence.text, showFurigana: $showFurigana, font: .title3)
                        .textSelection(.enabled)
                }
            }

            Section("Reading (ひらがな)") {
                if isEditing {
                    TextField("Reading", text: $draftReading, axis: .vertical)
                        .lineLimit(2...10)
                } else {
                    Text(sentence.reading ?? "—")
                        .font(.body)
                        .foregroundStyle(sentence.reading == nil ? .tertiary : .secondary)
                        .textSelection(.enabled)
                }
            }

            Section(translationSectionTitle) {
                if isEditing {
                    TextField("Translation", text: $draftTranslation, axis: .vertical)
                        .lineLimit(2...10)
                } else {
                    Text(sentence.translation ?? "—")
                        .font(.body)
                        .foregroundStyle(sentence.translation == nil ? .tertiary : .primary)
                        .textSelection(.enabled)
                }
            }

            Section("Captured") {
                Text(sentence.createdAt.formatted(date: .long, time: .shortened))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let image = sourceImage {
                    Button {
                        showFullImage = true
                    } label: {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                Button {
                    showClozePicker = true
                } label: {
                    Label(
                        sentence.hasClozes ? "Pick more clozes" : "Pick clozes",
                        systemImage: "highlighter"
                    )
                }
                .disabled(isEditing)
            } header: {
                Text("Clozes")
            } footer: {
                if sentence.hasClozes {
                    Text("Editing the sentence is locked while clozes exist.")
                }
            }

            if !sentence.clozes.isEmpty {
                Section("Picked words (\(sentence.clozes.count))") {
                    ForEach(sentence.clozes.sorted(by: { $0.startOffset < $1.startOffset })) { cloze in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cloze.surfaceForm).font(.body)
                            Text("\(cloze.lemma) · \(cloze.reading) · \(cloze.partOfSpeech)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        showDrillReview = true
                    } label: {
                        Label("Quiz these clozes", systemImage: "play.circle.fill")
                    }
                    .disabled(drillCards.isEmpty)
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete sentence", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Sentence")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showClozePicker) {
            ClozePickerView(sentence: sentence)
        }
        .sheet(isPresented: $showDrillReview) {
            ReviewView(drillCards: drillCards)
        }
        .fullScreenCover(isPresented: $showFullImage) {
            if let image = sourceImage {
                FullImageView(image: image) { showFullImage = false }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                FuriganaToggleButton(showFurigana: $showFurigana)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button("Done") {
                        let trimmedText = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedText.isEmpty {
                            sentence.text = trimmedText
                            sentence.reading = draftReading.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                            sentence.translation = draftTranslation.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                            try? modelContext.save()
                        }
                        isEditing = false
                    }
                } else if !sentence.hasClozes {
                    Button("Edit") {
                        draftText = sentence.text
                        draftReading = sentence.reading ?? ""
                        draftTranslation = sentence.translation ?? ""
                        isEditing = true
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete this sentence?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                modelContext.delete(sentence)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private extension SentenceDetailView {
    var translationSectionTitle: String {
        let code = sentence.translationLanguage
        let englishLocale = Locale(identifier: "en")
        if let name = englishLocale.localizedString(forIdentifier: code), !name.isEmpty {
            return "Translation (\(name))"
        }
        return "Translation"
    }

    var drillCards: [WordCard] {
        var seen: Set<UUID> = []
        var result: [WordCard] = []
        for cloze in sentence.clozes {
            guard let card = cloze.wordCard, !card.isKnown, !seen.contains(card.id) else { continue }
            seen.insert(card.id)
            result.append(card)
        }
        return result
    }

    var sourceImage: UIImage? {
        guard let path = sentence.capturedPage?.photoRelativePath else { return nil }
        return PhotoStore.loadImage(relativePath: path)
    }
}

private struct FullImageView: View {
    let image: UIImage
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            ZoomableImageView(image: image)
                .ignoresSafeArea()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .padding()
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
