import Observation
import SwiftUI

@MainActor
struct Stage42ReducerUnidirectionalArchitectureView: View {
    @Environment(\.itemRepository) private var itemRepository

    @State private var store = Stage42CatalogStore()
    @State private var mutableModel = Stage42MutableCatalogModel()
    @State private var localDraft = "Do we need explicit actions for this change?"

    var body: some View {
        NavigationStack {
            List {
                Section("Stage 42 - Reducer / unidirectional architecture") {
                    Text("Concept")
                        .font(.headline)
                    Text("Reducer style makes transitions explicit: state changes only through actions and a reducer function.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Problem")
                        .font(.headline)
                    Text("As features grow, direct ad-hoc mutations can hide why state changed and make flows harder to test and debug.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Prediction")
                        .font(.headline)
                    Text("Before running: which panel will make it easier to explain every state transition from logs alone?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Implementation") {
                    Stage42ComparisonCard(
                        localDraft: $localDraft,
                        storeState: store.state,
                        mutableModel: mutableModel,
                        onResetReducer: { store.send(.resetTapped) },
                        onResetMutable: { mutableModel.reset() }
                    )

                    Stage42ReducerCard(
                        store: store,
                        repository: itemRepository
                    )

                    Stage42MutableCard(
                        model: mutableModel,
                        repository: itemRepository
                    )
                }

                Section("Run") {
                    Text("1) Type distinct queries in both panels and toggle favorites.")
                    Text("2) Trigger load in both panels.")
                    Text("3) In the reducer panel, watch action names in logs and the transition counter.")
                    Text("4) Reset each side independently and compare ownership and lifetime.")
                }

                Section("Explanation") {
                    Text("Reducer architecture gives explicit transitions and predictable mutation points. That improves auditability and can scale for larger teams.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("The tradeoff is boilerplate: state, action enums, reducer logic, and effect plumbing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("For small features, a focused observable model may stay clearer. For high-complexity flows, reducers can repay the extra ceremony.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Refactor") {
                    Text("A practical direction is hybrid: keep simple local concerns mutable and direct, while moving critical workflows to reducer-managed transitions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Only keep reducer boilerplate if explicit transitions are actively helping debugging, testing, or team coordination.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Takeaway") {
                    Text("- Reducers optimize for explicitness and predictability.")
                    Text("- Explicitness costs boilerplate and indirection.")
                    Text("- Choose by feature complexity, not ideology.")
                    Text("- Keep ownership and lifetime visible regardless of style.")
                }
            }
            .navigationTitle("Reducer Review")
        }
        .onAppear {
            LabLog.event("Stage42ReducerUnidirectionalArchitectureView onAppear")
        }
    }
}

@MainActor
@Observable
final class Stage42CatalogStore {
    var state = Stage42CatalogState()

    init() {
        LabLog.event("Stage42CatalogStore init")
    }

    deinit {
        LabLog.event("Stage42CatalogStore deinit")
    }

    func send(_ action: Stage42CatalogAction, repository: (any ItemRepository)? = nil) {
        let effect = Stage42CatalogReducer.reduce(state: &state, action: action)

        switch effect {
        case .none:
            break
        case .loadItems:
            guard let repository else {
                LabLog.event("Stage42 reducer effect skipped: missing repository")
                return
            }

            Task {
                do {
                    let items = try await repository.featuredItems()
                    send(.loadFinished(.success(items)))
                } catch {
                    send(.loadFinished(.failure(error)))
                }
            }
        }
    }
}

struct Stage42CatalogState {
    var query = ""
    var favoriteIDs: Set<CatalogItem.ID> = ["identity"]
    var loadSummary = "Not loaded"
    var loadCount = 0
    var transitionCount = 0

    var filteredItems: [CatalogItem] {
        guard !query.isEmpty else { return CatalogItem.samples }
        return CatalogItem.samples.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }
}

enum Stage42CatalogAction {
    case queryChanged(String)
    case favoriteTapped(CatalogItem.ID)
    case loadTapped
    case loadFinished(Result<[CatalogItem], Error>)
    case resetTapped
}

enum Stage42CatalogEffect {
    case none
    case loadItems
}

enum Stage42CatalogReducer {
    static func reduce(state: inout Stage42CatalogState, action: Stage42CatalogAction) -> Stage42CatalogEffect {
        state.transitionCount += 1

        switch action {
        case let .queryChanged(text):
            state.query = text
            LabLog.event("Stage42 action: queryChanged -> \(text)")
            return .none

        case let .favoriteTapped(itemID):
            if state.favoriteIDs.contains(itemID) {
                state.favoriteIDs.remove(itemID)
            } else {
                state.favoriteIDs.insert(itemID)
            }
            LabLog.event("Stage42 action: favoriteTapped -> \(itemID)")
            return .none

        case .loadTapped:
            state.loadSummary = "Loading..."
            LabLog.event("Stage42 action: loadTapped")
            return .loadItems

        case let .loadFinished(result):
            switch result {
            case let .success(items):
                state.loadCount += 1
                state.loadSummary = "Loaded \(items.count) item(s) via reducer store"
                LabLog.event("Stage42 action: loadFinished success")
            case let .failure(error):
                state.loadSummary = "Load failed: \(error.localizedDescription)"
                LabLog.event("Stage42 action: loadFinished failure -> \(error.localizedDescription)")
            }
            return .none

        case .resetTapped:
            state = Stage42CatalogState()
            LabLog.event("Stage42 action: resetTapped")
            return .none
        }
    }
}

@MainActor
@Observable
final class Stage42MutableCatalogModel {
    var query = ""
    var favoriteIDs: Set<CatalogItem.ID> = ["identity"]
    var loadSummary = "Not loaded"
    var loadCount = 0

    init() {
        LabLog.event("Stage42MutableCatalogModel init")
    }

    deinit {
        LabLog.event("Stage42MutableCatalogModel deinit")
    }

    var filteredItems: [CatalogItem] {
        guard !query.isEmpty else { return CatalogItem.samples }
        return CatalogItem.samples.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    func toggleFavorite(_ itemID: CatalogItem.ID) {
        if favoriteIDs.contains(itemID) {
            favoriteIDs.remove(itemID)
        } else {
            favoriteIDs.insert(itemID)
        }
    }

    func load(using repository: any ItemRepository) async {
        do {
            let items = try await repository.featuredItems()
            loadCount += 1
            loadSummary = "Loaded \(items.count) item(s) via mutable model"
        } catch {
            loadSummary = "Load failed: \(error.localizedDescription)"
        }
    }

    func reset() {
        query = ""
        favoriteIDs = ["identity"]
        loadSummary = "Not loaded"
        loadCount = 0
    }
}

private struct Stage42ComparisonCard: View {
    @Binding var localDraft: String
    let storeState: Stage42CatalogState
    let mutableModel: Stage42MutableCatalogModel
    let onResetReducer: () -> Void
    let onResetMutable: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ownership inventory")
                .font(.headline)

            TextField("Local draft (@State)", text: $localDraft)
                .textFieldStyle(.roundedBorder)

            Text("Reducer transitions: \(storeState.transitionCount)")
                .font(.caption)

            Text("Reducer state -> query='\(storeState.query)', favorites=\(storeState.favoriteIDs.count), loads=\(storeState.loadCount)")
                .font(.caption)

            Text("Mutable model -> query='\(mutableModel.query)', favorites=\(mutableModel.favoriteIDs.count), loads=\(mutableModel.loadCount)")
                .font(.caption)

            HStack {
                Button("Reset reducer") {
                    onResetReducer()
                }

                Button("Reset mutable model") {
                    onResetMutable()
                }
            }

            Text("The local draft stays view-owned. Both side models reset independently based on owner choice.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct Stage42ReducerCard: View {
    let store: Stage42CatalogStore
    let repository: any ItemRepository

    var body: some View {
        @Bindable var store = store

        VStack(alignment: .leading, spacing: 8) {
            Text("Reducer + Action pipeline")
                .font(.headline)

            TextField(
                "Reducer query",
                text: Binding(
                    get: { store.state.query },
                    set: { store.send(.queryChanged($0)) }
                )
            )
            .textFieldStyle(.roundedBorder)

            Button("Load via reducer action") {
                store.send(.loadTapped, repository: repository)
            }

            Text(store.state.loadSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(store.state.filteredItems) { item in
                Stage42FavoriteRow(
                    item: item,
                    isFavorite: store.state.favoriteIDs.contains(item.id),
                    onToggle: { store.send(.favoriteTapped(item.id)) }
                )
            }

            Text("All mutations route through send(action), making transitions explicit and loggable.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct Stage42MutableCard: View {
    let model: Stage42MutableCatalogModel
    let repository: any ItemRepository

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 8) {
            Text("Direct mutable model")
                .font(.headline)

            TextField("Mutable query", text: $model.query)
                .textFieldStyle(.roundedBorder)

            Button("Load via model method") {
                let repository = repository
                Task {
                    await model.load(using: repository)
                }
            }

            Text(model.loadSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(model.filteredItems) { item in
                Stage42FavoriteRow(
                    item: item,
                    isFavorite: model.favoriteIDs.contains(item.id),
                    onToggle: { model.toggleFavorite(item.id) }
                )
            }

            Text("This style can stay clearer for small features because there is less ceremony.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct Stage42FavoriteRow: View {
    let item: CatalogItem
    let isFavorite: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline.bold())
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(.yellow)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Stage 42 - default") {
    Stage42ReducerUnidirectionalArchitectureView()
        .environment(AppRouter())
        .environment(AppUIState())
        .environment(Session())
        .environment(\.itemRepository, PreviewItemRepository(name: "Stage 42 preview"))
}

#Preview("Stage 42 - signed out") {
    Stage42ReducerUnidirectionalArchitectureView()
        .environment(AppRouter())
        .environment(AppUIState())
        .environment(Session(profile: nil))
        .environment(\.itemRepository, TestItemRepository(name: "Stage 42 test"))
}
