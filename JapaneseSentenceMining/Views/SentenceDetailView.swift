import SwiftData
import SwiftUI

struct SentenceDetailView: View {
    @Bindable var sentence: Sentence
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LocalizationStore.self) private var loc

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
            Section(loc.t("sentenceDetail.section.original")) {
                if isEditing {
                    TextField(loc.t("sentenceDetail.field.original.placeholder"), text: $draftText, axis: .vertical)
                        .lineLimit(2...10)
                } else {
                    JapaneseText(text: sentence.text, showFurigana: $showFurigana, font: .title3)
                        .textSelection(.enabled)
                }
            }

            Section(loc.t("sentenceDetail.section.reading")) {
                if isEditing {
                    TextField(loc.t("sentenceDetail.field.reading.placeholder"), text: $draftReading, axis: .vertical)
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
                    TextField(loc.t("sentenceDetail.field.translation.placeholder"), text: $draftTranslation, axis: .vertical)
                        .lineLimit(2...10)
                } else {
                    Text(sentence.translation ?? "—")
                        .font(.body)
                        .foregroundStyle(sentence.translation == nil ? .tertiary : .primary)
                        .textSelection(.enabled)
                }
            }

            Section(loc.t("sentenceDetail.section.captured")) {
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
                        sentence.hasClozes ? loc.t("sentenceDetail.pickMoreClozes") : loc.t("sentenceDetail.pickClozes"),
                        systemImage: "highlighter"
                    )
                }
                .disabled(isEditing)
            } header: {
                Text(loc.t("sentenceDetail.section.clozes"))
            } footer: {
                if sentence.hasClozes {
                    Text(loc.t("sentenceDetail.clozes.editLocked"))
                }
            }

            if !sentence.clozes.isEmpty {
                Section(loc.t("sentenceDetail.section.pickedWords", String(sentence.clozes.count))) {
                    ForEach(sentence.clozes.sorted(by: { $0.startOffset < $1.startOffset })) { cloze in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cloze.surfaceForm).font(.body)
                            Text(loc.t("sentenceDetail.clozeMeta", cloze.lemma, cloze.reading, cloze.partOfSpeech))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        showDrillReview = true
                    } label: {
                        Label(loc.t("sentenceDetail.quizClozes"), systemImage: "play.circle.fill")
                    }
                    .disabled(drillCards.isEmpty)
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label(loc.t("sentenceDetail.delete"), systemImage: "trash")
                }
            }
        }
        .navigationTitle(loc.t("sentenceDetail.title"))
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
                    Button(loc.t("common.done")) {
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
                    Button(loc.t("common.edit")) {
                        draftText = sentence.text
                        draftReading = sentence.reading ?? ""
                        draftTranslation = sentence.translation ?? ""
                        isEditing = true
                    }
                }
            }
        }
        .confirmationDialog(
            loc.t("sentenceDetail.deleteConfirm.title"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(loc.t("common.delete"), role: .destructive) {
                modelContext.delete(sentence)
                try? modelContext.save()
                dismiss()
            }
            Button(loc.t("common.cancel"), role: .cancel) {}
        }
    }
}

private extension SentenceDetailView {
    var translationSectionTitle: String {
        let code = sentence.translationLanguage
        let englishLocale = Locale(identifier: "en")
        if let name = englishLocale.localizedString(forIdentifier: code), !name.isEmpty {
            return loc.t("sentenceDetail.section.translationNamed", name)
        }
        return loc.t("sentenceDetail.section.translationGeneric")
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
