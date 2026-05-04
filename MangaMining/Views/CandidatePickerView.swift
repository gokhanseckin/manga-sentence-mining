import SwiftUI

struct CandidatePickerView: View {
    let candidates: [SentenceCandidate]
    var onSave: ([SentenceCandidate]) -> Void
    var onCancel: () -> Void

    @State private var editable: [EditableCandidate]
    @State private var selected: Set<UUID>

    init(
        candidates: [SentenceCandidate],
        onSave: @escaping ([SentenceCandidate]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.candidates = candidates
        self.onSave = onSave
        self.onCancel = onCancel
        let initial = candidates.map {
            EditableCandidate(id: $0.id, text: $0.text, reading: $0.reading, translationTr: $0.translationTr)
        }
        _editable = State(initialValue: initial)
        _selected = State(initialValue: Set(initial.map(\.id)))
    }

    struct EditableCandidate: Identifiable {
        let id: UUID
        var text: String
        var reading: String
        var translationTr: String
    }

    var body: some View {
        List {
            Section {
                ForEach($editable) { $row in
                    HStack(alignment: .top, spacing: 12) {
                        Toggle("", isOn: Binding(
                            get: { selected.contains(row.id) },
                            set: { isOn in
                                if isOn { selected.insert(row.id) } else { selected.remove(row.id) }
                            }
                        ))
                        .labelsHidden()
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Original (日本語)", text: $row.text, axis: .vertical)
                                .font(.body)
                                .textFieldStyle(.plain)
                            TextField("Reading (ひらがな)", text: $row.reading, axis: .vertical)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .textFieldStyle(.plain)
                            TextField("Translation (Türkçe)", text: $row.translationTr, axis: .vertical)
                                .font(.callout)
                                .textFieldStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } footer: {
                Text("Edit any line before saving. Unselected items are discarded.")
            }
        }
        .navigationTitle("Pick sentences")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) { onCancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let picked = editable
                        .filter { selected.contains($0.id) }
                        .map { row -> SentenceCandidate in
                            let original = candidates.first(where: { $0.id == row.id })
                            return SentenceCandidate(
                                text: row.text,
                                reading: row.reading,
                                translationTr: row.translationTr,
                                sourceRegions: original?.sourceRegions ?? []
                            )
                        }
                        .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    onSave(picked)
                }
                .disabled(selected.isEmpty)
            }
        }
    }
}
