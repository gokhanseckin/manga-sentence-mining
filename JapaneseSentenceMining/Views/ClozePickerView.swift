import SwiftData
import SwiftUI

struct ClozePickerView: View {
    let sentence: Sentence
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings
    @Environment(LocalizationStore.self) private var loc

    @State private var tokens: [JapaneseToken] = []
    @State private var selectedTokenIDs: Set<Int> = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showFurigana = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView(loc.t("clozePicker.tokenizing"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let loadError {
                    ContentUnavailableView(
                        loc.t("clozePicker.error.title"),
                        systemImage: "exclamationmark.triangle",
                        description: Text(loadError)
                    )
                } else {
                    content
                }
            }
            .navigationTitle(loc.t("clozePicker.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(loc.t("common.cancel")) { dismiss() }
                }
                ToolbarSpacer(.fixed, placement: .topBarLeading)
                ToolbarItem(placement: .topBarLeading) {
                    FuriganaToggleButton(showFurigana: $showFurigana)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(confirmLabel) {
                        confirmSelection()
                    }
                    .disabled(selectedTokenIDs.isEmpty)
                }
            }
        }
        .task { await loadTokens() }
    }

    private var confirmLabel: String {
        selectedTokenIDs.isEmpty ? loc.t("common.save") : loc.t("clozePicker.saveWithCount", String(selectedTokenIDs.count))
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(loc.t("clozePicker.instructions"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 6, lineSpacing: 8) {
                    ForEach(Array(tokens.enumerated()), id: \.offset) { idx, token in
                        TokenChip(
                            token: token,
                            state: chipState(for: idx, token: token),
                            showFurigana: showFurigana
                        ) {
                            toggleSelection(idx, token: token)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
    }

    enum ChipState { case selectable, selected, alreadyClozed }

    private func chipState(for idx: Int, token: JapaneseToken) -> ChipState {
        if isAlreadyClozed(token) { return .alreadyClozed }
        if selectedTokenIDs.contains(idx) { return .selected }
        return .selectable
    }

    private func toggleSelection(_ idx: Int, token: JapaneseToken) {
        guard !isAlreadyClozed(token) else { return }
        if selectedTokenIDs.contains(idx) {
            selectedTokenIDs.remove(idx)
        } else {
            selectedTokenIDs.insert(idx)
        }
    }

    private func isAlreadyClozed(_ token: JapaneseToken) -> Bool {
        let (start, end) = offsets(for: token)
        return sentence.clozes.contains { existing in
            // Overlap test: ranges intersect if neither is wholly before the other.
            start < existing.endOffset && existing.startOffset < end
        }
    }

    private func offsets(for token: JapaneseToken) -> (Int, Int) {
        let text = sentence.text
        let start = text.distance(from: text.startIndex, to: token.range.lowerBound)
        let end = text.distance(from: text.startIndex, to: token.range.upperBound)
        return (start, end)
    }

    private func loadTokens() async {
        let text = sentence.text
        do {
            let result = try await JapaneseTokenizer.shared.tokenize(text)
            await MainActor.run {
                self.tokens = result
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.loadError = String(describing: error)
                self.isLoading = false
            }
        }
    }

    private func confirmSelection() {
        var newCards: [WordCard] = []
        for idx in selectedTokenIDs.sorted() {
            let token = tokens[idx]
            let (start, end) = offsets(for: token)
            let cloze = Cloze(
                sentence: sentence,
                startOffset: start,
                endOffset: end,
                surfaceForm: token.surface,
                lemma: token.lemma,
                reading: token.reading,
                partOfSpeech: token.partOfSpeech
            )
            modelContext.insert(cloze)
            // First-time clozes for a lemma will be auto-linked below across
            // all existing sentences. Existing cards just attach normally.
            let lemma = token.lemma
            var probe = FetchDescriptor<WordCard>(predicate: #Predicate { $0.lemma == lemma })
            probe.fetchLimit = 1
            let isNew = ((try? modelContext.fetch(probe))?.isEmpty) ?? true
            let card = SchedulingService.getOrCreateWordCard(
                forLemma: token.lemma,
                reading: token.reading,
                partOfSpeech: token.partOfSpeech,
                in: modelContext,
                settings: settings
            )
            cloze.wordCard = card
            // Attach a denormalized snapshot of the source sentence so review
            // context survives iCloud sync to a device that doesn't have this
            // Sentence/Page locally.
            card.addSnapshot(SourceSnapshot(
                sentenceText: sentence.text,
                reading: sentence.reading ?? "",
                translation: sentence.translation ?? "",
                translationLanguage: sentence.translationLanguage,
                pageId: sentence.capturedPage?.id,
                capturedAt: sentence.createdAt
            ))
            if isNew { newCards.append(card) }
        }
        try? modelContext.save()
        let cards = newCards
        Task {
            for card in cards {
                await SentenceAutoLinker.autoLink(card: card, in: modelContext)
            }
        }
        dismiss()
    }
}

private struct TokenChip: View {
    let token: JapaneseToken
    let state: ClozePickerView.ChipState
    let showFurigana: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            chipContent
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(background)
                .foregroundStyle(foreground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(state == .alreadyClozed)
    }

    @ViewBuilder
    private var chipContent: some View {
        if showFurigana {
            VStack(spacing: 1) {
                Text(shouldAnnotate ? katakanaToHiragana(token.reading) : " ")
                    .font(.caption2)
                Text(token.surface)
                    .font(.title3)
            }
        } else {
            Text(token.surface).font(.title3)
        }
    }

    private var shouldAnnotate: Bool {
        let reading = token.reading
        guard !reading.isEmpty, reading != "*" else { return false }
        return token.surface != reading
            && token.surface.unicodeScalars.contains { scalar in
                (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value)
            }
    }

    private func katakanaToHiragana(_ s: String) -> String {
        String(s.unicodeScalars.map { scalar -> Character in
            if (0x30A1...0x30F6).contains(scalar.value),
               let converted = Unicode.Scalar(scalar.value - 0x60) {
                return Character(converted)
            }
            return Character(scalar)
        })
    }

    private var background: some ShapeStyle {
        switch state {
        case .selectable: return AnyShapeStyle(Color(.secondarySystemBackground))
        case .selected: return AnyShapeStyle(Color.accentColor.opacity(0.85))
        case .alreadyClozed: return AnyShapeStyle(Color(.tertiarySystemBackground))
        }
    }

    private var foreground: some ShapeStyle {
        switch state {
        case .selectable: return AnyShapeStyle(Color.primary)
        case .selected: return AnyShapeStyle(Color.white)
        case .alreadyClozed: return AnyShapeStyle(Color.secondary)
        }
    }
}
