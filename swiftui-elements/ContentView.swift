import SwiftUI

@MainActor
struct ContentView: View {
    @State private var parentRevision = 0
    @State private var model = FavoritesModel()

    init() {
        LabLog.event("ContentView init")
    }

    var body: some View {
        let _ = LabLog.event("ContentView body")

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Stage 4: Observation")
                    .font(.title.bold())

                Text("This exercise separates ownership from observation. ContentView owns one @Observable model in @State, while child views observe only the properties they actually read.")
                    .foregroundStyle(.secondary)

                Divider()

                parentControls
                observationQuestionCard

                FavoriteSummaryView(model: model)
                CatalogListView(model: model)
                DraftEditorView(model: model)
                DiagnosticsPanelView(model: model)
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

            Button("Recompute parent view") {
                parentRevision += 1
                LabLog.event("parentRevision changed to \(parentRevision)")
            }

            Button("Replace observable model instance") {
                model = FavoritesModel()
                LabLog.event("ContentView replaced its @State-owned FavoritesModel")
            }

            Text("Changing parentRevision recreates transient View values, but keeps the same model instance. Replacing the model changes ownership/lifetime, not just observation.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var observationQuestionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prediction")
                .font(.headline)

            Text("Before tapping a control, predict which child body logs will print. A view should invalidate when it reads the property that changed, not merely because the model object exists.")

            Text("@Observable makes the model observable. @State owns the model lifetime here. @Bindable is only used where a child needs bindings into editable model properties.")
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

@Observable
private final class FavoritesModel {
    var items: [CatalogItem]
    var favoriteIDs: Set<CatalogItem.ID>
    var draftTitle: String
    var draftNotes: String
    var diagnosticsTick = 0

    init(
        items: [CatalogItem] = CatalogItem.samples,
        favoriteIDs: Set<CatalogItem.ID> = [CatalogItem.samples[0].id],
        draftTitle: String = "Observation field notes",
        draftNotes: String = "Edit this text and watch which bodies evaluate."
    ) {
        self.items = items
        self.favoriteIDs = favoriteIDs
        self.draftTitle = draftTitle
        self.draftNotes = draftNotes
        LabLog.event("FavoritesModel init")
    }

    deinit {
        LabLog.event("FavoritesModel deinit")
    }

    func toggleFavorite(_ item: CatalogItem) {
        if favoriteIDs.contains(item.id) {
            favoriteIDs.remove(item.id)
        } else {
            favoriteIDs.insert(item.id)
        }

        LabLog.event("FavoritesModel toggled favorite for \(item.title)")
    }

    func resetDraft() {
        draftTitle = "Observation field notes"
        draftNotes = "Edit this text and watch which bodies evaluate."
        LabLog.event("FavoritesModel reset draft fields")
    }
}

private struct CatalogItem: Identifiable, Equatable {
    let id: String
    var title: String
    var subtitle: String

    static let samples = [
        CatalogItem(id: "identity", title: "Identity", subtitle: "What is the same view over time?"),
        CatalogItem(id: "state", title: "State", subtitle: "Who owns the source of truth?"),
        CatalogItem(id: "observation", title: "Observation", subtitle: "Which property did this body read?")
    ]
}

private struct FavoriteSummaryView: View {
    let model: FavoritesModel

    init(model: FavoritesModel) {
        self.model = model
        LabLog.event("FavoriteSummaryView init")
    }

    var body: some View {
        let _ = LabLog.event("FavoriteSummaryView body")

        VStack(alignment: .leading, spacing: 8) {
            Text("Favorite summary")
                .font(.headline)

            Text("Favorites: \(model.favoriteIDs.count)")
                .font(.title3)

            Text("This view reads favoriteIDs, but not draftTitle, draftNotes, or diagnosticsTick.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct CatalogListView: View {
    let model: FavoritesModel

    init(model: FavoritesModel) {
        self.model = model
        LabLog.event("CatalogListView init")
    }

    var body: some View {
        let _ = LabLog.event("CatalogListView body")

        VStack(alignment: .leading, spacing: 12) {
            Text("Catalog rows")
                .font(.headline)

            ForEach(model.items) { item in
                Button {
                    model.toggleFavorite(item)
                } label: {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.subheadline.bold())
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: model.favoriteIDs.contains(item.id) ? "star.fill" : "star")
                            .foregroundStyle(.yellow)
                            .accessibilityLabel(model.favoriteIDs.contains(item.id) ? "Favorite" : "Not favorite")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if item.id != model.items.last?.id {
                    Divider()
                }
            }

            Text("This view reads items and favoriteIDs because row identity/content and star state depend on them.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct DraftEditorView: View {
    @Bindable var model: FavoritesModel

    init(model: FavoritesModel) {
        self.model = model
        LabLog.event("DraftEditorView init")
    }

    var body: some View {
        let _ = LabLog.event("DraftEditorView body")

        VStack(alignment: .leading, spacing: 8) {
            Text("Editable draft")
                .font(.headline)

            Text("@Bindable projects bindings into an @Observable model. It does not create or own the model.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Title", text: $model.draftTitle)
                .textFieldStyle(.roundedBorder)

            TextField("Notes", text: $model.draftNotes, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)

            Button("Reset draft fields") {
                model.resetDraft()
            }
        }
        .stageCard()
    }
}

private struct DiagnosticsPanelView: View {
    let model: FavoritesModel

    init(model: FavoritesModel) {
        self.model = model
        LabLog.event("DiagnosticsPanelView init")
    }

    var body: some View {
        let _ = LabLog.event("DiagnosticsPanelView body")

        VStack(alignment: .leading, spacing: 8) {
            Text("Diagnostics-only property")
                .font(.headline)

            Text("Tick: \(model.diagnosticsTick)")

            Button("Increment diagnosticsTick") {
                model.diagnosticsTick += 1
                LabLog.event("FavoritesModel diagnosticsTick changed to \(model.diagnosticsTick)")
            }

            Text("Only this panel reads diagnosticsTick. Use it to test property-specific observation.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
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
