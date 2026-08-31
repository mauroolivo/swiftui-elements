import SwiftUI

@MainActor
struct ContentView: View {
    @State private var parentRevision = 0
    @State private var draft = ItemDraft.sample

    init() {
        LabLog.event("ContentView init")
    }

    var body: some View {
        let _ = LabLog.event("ContentView body")

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Stage 3: Local State Ownership")
                    .font(.title.bold())

                Text("Exercise B refactors the duplicated-state bug into one parent-owned source of truth. The editor receives a binding; the preview receives a read-only value plus an action closure.")
                    .foregroundStyle(.secondary)

                Divider()

                parentControls
                ownershipQuestionCard

                VStack(alignment: .leading, spacing: 12) {
                    Text("Refactored component split")
                        .font(.headline)

                    Text("ContentView owns the draft. Children receive only the access they need.")
                        .foregroundStyle(.secondary)

                    ItemEditor(draft: $draft)
                    ItemPreview(draft: draft) {
                        draft.isFavorite.toggle()
                        LabLog.event("ContentView handled preview favorite toggle; isFavorite is now \(draft.isFavorite)")
                    }
                }
                .stageCard()
            }
            .padding()
        }
        .onAppear {
            LabLog.event("ContentView onAppear")
        }
        .onDisappear {
            LabLog.event("ContentView onDisappear")
        }
    }

    private var parentControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Parent revision: \(parentRevision)")

            Button("Recompute parent") {
                parentRevision += 1
                LabLog.event("parentRevision changed to \(parentRevision)")
            }

            Button("Reset parent-owned draft") {
                draft = .sample
                LabLog.event("ContentView reset parent-owned draft")
            }
        }
        .stageCard()
    }

    private var ownershipQuestionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Question")
                .font(.headline)

            Text("Who owns the editable item draft: the parent, the editor, or the preview?")

            Text("In this refactored version, ContentView owns it. The editor can mutate through a binding. The preview can display it and emit actions, but does not own it.")
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct ItemDraft: Equatable {
    var title: String
    var subtitle: String
    var isFavorite: Bool
    var priority: Int

    static let sample = ItemDraft(
        title: "SwiftUI Identity Field Notes",
        subtitle: "State ownership is not automatic",
        isFavorite: false,
        priority: 2
    )
}

private struct ItemEditor: View {
    @Binding var draft: ItemDraft

    init(draft: Binding<ItemDraft>) {
        _draft = draft
        LabLog.event("ItemEditor init")
    }

    var body: some View {
        let _ = LabLog.event("ItemEditor body")

        VStack(alignment: .leading, spacing: 8) {
            Text("Editor")
                .font(.subheadline.bold())

            Text("Receives Binding<ItemDraft>; it does not own a private copy.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Title", text: $draft.title)
                .textFieldStyle(.roundedBorder)

            TextField("Subtitle", text: $draft.subtitle)
                .textFieldStyle(.roundedBorder)

            Toggle("Favorite", isOn: $draft.isFavorite)

            Stepper("Priority: \(draft.priority)", value: $draft.priority, in: 1...5)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            LabLog.event("ItemEditor onAppear")
        }
        .onDisappear {
            LabLog.event("ItemEditor onDisappear")
        }
    }
}

private struct ItemPreview: View {
    let draft: ItemDraft
    let onToggleFavorite: () -> Void

    init(draft: ItemDraft, onToggleFavorite: @escaping () -> Void) {
        self.draft = draft
        self.onToggleFavorite = onToggleFavorite
        LabLog.event("ItemPreview init")
    }

    var body: some View {
        let _ = LabLog.event("ItemPreview body")

        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.subheadline.bold())

            Text("Receives ItemDraft value; it does not own or mutate local draft state.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(draft.title)
                    .font(.headline)

                Text(draft.subtitle)
                    .foregroundStyle(.secondary)

                HStack {
                    Label(draft.isFavorite ? "Favorite" : "Not favorite", systemImage: draft.isFavorite ? "star.fill" : "star")
                    Spacer()
                    Text("Priority \(draft.priority)")
                }
                .font(.caption)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 10))

            Button("Ask parent to toggle favorite") {
                onToggleFavorite()
                LabLog.event("ItemPreview emitted toggle favorite action")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            LabLog.event("ItemPreview onAppear")
        }
        .onDisappear {
            LabLog.event("ItemPreview onDisappear")
        }
    }
}

private struct StageCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

private extension View {
    func stageCard() -> some View {
        modifier(StageCardModifier())
    }
}

private enum LabLog {
    nonisolated static func event(_ message: String) {
        print("🧪 \(message)")
    }
}

#Preview {
    ContentView()
}
