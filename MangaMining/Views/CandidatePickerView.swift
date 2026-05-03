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
        let initial = candidates.map { EditableCandidate(id: $0.id, text: $0.text) }
        _editable = State(initialValue: initial)
        _selected = State(initialValue: Set(initial.map(\.id)))
    }

    struct EditableCandidate: Identifiable {
        let id: UUID
        var text: String
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
                        TextField("Sentence", text: $row.text, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                }
            } footer: {
                Text("Edit any sentence before saving. Unselected items are discarded.")
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
