import Observation
import SwiftUI

@MainActor
struct Stage29FormsAndEditingArchitectureView: View {
    @State private var model = Stage29ItemEditorModel()
    @State private var draft = Stage29ItemDraft(from: .sample)
    @State private var isDraftEditorActive = false
    @FocusState private var focusedField: Stage29FocusedField?

    var body: some View {
        @Bindable var editableModel = model

        Form {
            Section("Stage 29 - Forms and editing architecture") {
                Text("Concept")
                    .font(.headline)
                Text("Form controls are input mechanics. Editing architecture decides ownership, source of truth, and whether edits are transactional.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Problem")
                    .font(.headline)
                Text("If a form mutates the live domain value directly, every keystroke becomes committed state. Cancel and validation become awkward.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Prediction")
                    .font(.headline)
                Text("Edit both sections below, then hit Cancel. Which section can reliably discard changes without reloading from persistence?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Persisted item snapshot (source of truth)") {
                Stage29SnapshotView(item: model.savedItem)
            }

            Section("Anti-pattern: editing the live domain object") {
                TextField("Title", text: $editableModel.liveItem.title)
                    .focused($focusedField, equals: .liveTitle)
                Picker("Category", selection: $editableModel.liveItem.category) {
                    ForEach(Stage29ItemCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                Toggle("Favorite", isOn: $editableModel.liveItem.isFavorite)
                TextField("Notes", text: $editableModel.liveItem.notes, axis: .vertical)
                    .lineLimit(2...4)

                Button("Commit direct edits") {
                    model.commitLiveEdits()
                }
                .buttonStyle(.borderedProminent)

                Button("Cancel attempt") {
                    model.cancelLiveEditingAttempt()
                }
                .buttonStyle(.bordered)

                Text("Every field mutation already touched live state. Cancel needs a full reset from saved data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Draft workflow: ItemDraft -> validate -> save/cancel") {
                if !isDraftEditorActive {
                    Button("Start draft editing") {
                        draft = Stage29ItemDraft(from: model.savedItem)
                        isDraftEditorActive = true
                        focusedField = .draftTitle
                        LabLog.event("Stage29 opened draft editor")
                    }
                } else {
                    TextField("Draft title", text: $draft.title)
                        .focused($focusedField, equals: .draftTitle)
                    Picker("Draft category", selection: $draft.category) {
                        ForEach(Stage29ItemCategory.allCases) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    Toggle("Draft favorite", isOn: $draft.isFavorite)
                    TextField("Draft notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(2...4)

                    if let validationMessage = draft.validationMessage {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    HStack {
                        Button("Cancel") {
                            draft = Stage29ItemDraft(from: model.savedItem)
                            isDraftEditorActive = false
                            focusedField = nil
                            LabLog.event("Stage29 canceled draft edits")
                        }
                        .buttonStyle(.bordered)

                        Button("Save draft") {
                            model.applyDraft(draft)
                            isDraftEditorActive = false
                            focusedField = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(draft.validationMessage != nil)
                    }
                }

                Text("Draft state is transactional UI state. The persisted item changes only on explicit Save.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Run") {
                Text("1) Type a new title in live editing, then tap Cancel attempt.")
                Text("2) Start draft editing, type changes, then tap Cancel and reopen the draft.")
                Text("3) Save a valid draft and compare snapshot + logs.")
            }

            Section("Event log") {
                if model.events.isEmpty {
                    Text("No events yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(model.events.enumerated()), id: \.offset) { _, event in
                        Text(event)
                            .font(.caption)
                    }
                }
            }

            Section("Takeaway") {
                Text("- Form controls are not the source of truth; state ownership is.")
                Text("- Draft state enables validation and true Save/Cancel semantics.")
                Text("- Persisted/domain objects should change at commit points, not every keystroke.")
            }
        }
        .onAppear {
            LabLog.event("Stage29FormsAndEditingArchitectureView onAppear")
        }
    }
}

private enum Stage29FocusedField: Hashable {
    case liveTitle
    case draftTitle
}

private struct Stage29SnapshotView: View {
    let item: Stage29Item

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(.headline)
            Text("Category: \(item.category.rawValue)")
                .font(.caption)
            Text("Favorite: \(item.isFavorite ? "yes" : "no")")
                .font(.caption)
            Text(item.notes.isEmpty ? "Notes: none" : "Notes: \(item.notes)")
                .font(.caption)
        }
    }
}

@MainActor
@Observable
private final class Stage29ItemEditorModel {
    var savedItem: Stage29Item
    var liveItem: Stage29Item
    var events: [String]

    init() {
        self.savedItem = .sample
        self.liveItem = .sample
        self.events = []
        record("Model initialized")
    }

    init(savedItem: Stage29Item) {
        self.savedItem = savedItem
        self.liveItem = savedItem
        self.events = []
        record("Model initialized")
    }

    func commitLiveEdits() {
        savedItem = liveItem
        record("Committed live edits directly")
    }

    func cancelLiveEditingAttempt() {
        liveItem = savedItem
        record("Reset live item from saved snapshot")
    }

    func applyDraft(_ draft: Stage29ItemDraft) {
        savedItem = draft.makeItem(id: savedItem.id)
        liveItem = savedItem
        record("Saved draft transaction")
    }

    private func record(_ message: String) {
        events.insert(message, at: 0)
        LabLog.event("Stage29ItemEditorModel: \(message)")
    }
}

private struct Stage29Item: Identifiable, Equatable {
    let id: String
    var title: String
    var category: Stage29ItemCategory
    var isFavorite: Bool
    var notes: String

    static let sample = Stage29Item(
        id: "stage29-item-1",
        title: "Rendering model notes",
        category: .article,
        isFavorite: false,
        notes: "Draft first, then commit."
    )
}

private struct Stage29ItemDraft: Equatable {
    var title: String
    var category: Stage29ItemCategory
    var isFavorite: Bool
    var notes: String

    init(from item: Stage29Item) {
        self.title = item.title
        self.category = item.category
        self.isFavorite = item.isFavorite
        self.notes = item.notes
    }

    var validationMessage: String? {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Title is required before saving." : nil
    }

    func makeItem(id: Stage29Item.ID) -> Stage29Item {
        Stage29Item(
            id: id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            isFavorite: isFavorite,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

private enum Stage29ItemCategory: String, CaseIterable, Identifiable {
    case article = "Article"
    case video = "Video"
    case interactiveLab = "Interactive Lab"

    var id: Self { self }
}

#Preview("Stage 29") {
    Stage29FormsAndEditingArchitectureView()
}
