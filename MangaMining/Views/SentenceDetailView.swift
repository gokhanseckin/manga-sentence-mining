import SwiftData
import SwiftUI

struct SentenceDetailView: View {
    @Bindable var sentence: Sentence
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var draft: String = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        Form {
            Section("Sentence") {
                if isEditing {
                    TextField("Sentence", text: $draft, axis: .vertical)
                        .lineLimit(2...10)
                } else {
                    Text(sentence.text)
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
                        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            sentence.text = trimmed
                            try? modelContext.save()
                        }
                        isEditing = false
                    }
                } else {
                    Button("Edit") {
                        draft = sentence.text
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
