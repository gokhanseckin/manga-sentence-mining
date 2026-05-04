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

    var body: some View {
        Form {
            Section("Original (日本語)") {
                if isEditing {
                    TextField("Original", text: $draftText, axis: .vertical)
                        .lineLimit(2...10)
                } else {
                    Text(sentence.text)
                        .font(.title3)
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

            Section("Translation (Türkçe)") {
                if isEditing {
                    TextField("Translation", text: $draftTranslation, axis: .vertical)
                        .lineLimit(2...10)
                } else {
                    Text(sentence.translationTr ?? "—")
                        .font(.body)
                        .foregroundStyle(sentence.translationTr == nil ? .tertiary : .primary)
                        .textSelection(.enabled)
                }
            }

            Section("Captured") {
                Text(sentence.createdAt.formatted(date: .long, time: .shortened))
                    .font(.callout)
                    .foregroundStyle(.secondary)
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button("Done") {
                        let trimmedText = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedText.isEmpty {
                            sentence.text = trimmedText
                            sentence.reading = draftReading.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                            sentence.translationTr = draftTranslation.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                            try? modelContext.save()
                        }
                        isEditing = false
                    }
                } else if !sentence.hasClozes {
                    Button("Edit") {
                        draftText = sentence.text
                        draftReading = sentence.reading ?? ""
                        draftTranslation = sentence.translationTr ?? ""
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

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
