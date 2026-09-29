import Observation
import SwiftUI

@MainActor
struct Stage41MVVMCriticallyEvaluatedView: View {
    @Environment(\.itemRepository) private var itemRepository

    @State private var viewModel = Stage41CatalogViewModel()
    @State private var featureModel = Stage41CatalogFeatureModel()
    @State private var localNote = "Which values really need a ViewModel owner?"

    var body: some View {
        NavigationStack {
            List {
                Section("Stage 41 - MVVM critically evaluated") {
                    Text("Concept")
                        .font(.headline)
                    Text("MVVM is one option, not a default law. In SwiftUI, plain @State and focused feature models already solve many ownership problems.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Problem")
                        .font(.headline)
                    Text("Teams often add a ViewModel for every screen, even when it only mirrors UI state and forwards calls.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Prediction")
                        .font(.headline)
                    Text("Before running: after recreating only one side, which values should reset? Should localNote survive both resets?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Implementation") {
                    Stage41ComparisonSummaryCard(
                        localNote: $localNote,
                        viewModel: viewModel,
                        featureModel: featureModel,
                        repositoryName: itemRepository.diagnosticName,
                        onResetViewModel: { viewModel = Stage41CatalogViewModel() },
                        onResetFeatureModel: { featureModel = Stage41CatalogFeatureModel() }
                    )

                    Stage41MVVMCard(
                        viewModel: viewModel,
                        repository: itemRepository
                    )

                    Stage41FeatureModelCard(
                        model: featureModel,
                        repository: itemRepository
                    )
                }

                Section("Run") {
                    Text("1) Type different query text in both cards and toggle favorites.")
                    Text("2) Trigger load on both cards and compare behavior.")
                    Text("3) Reset only the ViewModel, then only the feature model.")
                    Text("4) Observe that localNote survives both resets because it is plain view-owned @State.")
                }

                Section("Explanation") {
                    Text("Both cards can work. The key question is not style preference, but ownership and responsibilities.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("When a ViewModel mostly mirrors text fields, toggles, and tiny transforms, it can become extra indirection with little payoff.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("A dedicated ViewModel becomes useful when it provides real boundaries: cross-view coordination, async orchestration, adapter logic, or testable state transitions that are meaningful outside body composition.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Refactor") {
                    Text("If both implementations continue to duplicate behavior, keep one owner. Prefer the smaller owner that still keeps async work, mutation rules, and tests clear.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("In this stage, the feature model is usually enough. Add a ViewModel only when it earns its own responsibilities.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Takeaway") {
                    Text("- MVVM is a tool, not a default requirement.")
                    Text("- Start from ownership, lifetime, and behavior boundaries.")
                    Text("- Keep plain @State for local UI details.")
                    Text("- Add a ViewModel only when it reduces complexity rather than renaming it.")
                }
            }
            .navigationTitle("MVVM Review")
        }
        .onAppear {
            LabLog.event("Stage41MVVMCriticallyEvaluatedView onAppear")
        }
    }
}

@MainActor
@Observable
final class Stage41CatalogViewModel {
    var query = ""
    var favoriteIDs: Set<CatalogItem.ID> = ["identity"]
    var loadSummary = "Not loaded"
    var loadCount = 0

    init() {
        LabLog.event("Stage41CatalogViewModel init")
    }

    deinit {
        LabLog.event("Stage41CatalogViewModel deinit")
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
            loadSummary = "Loaded \(items.count) item(s) via ViewModel"
            LabLog.event("Stage41 ViewModel load from \(repository.diagnosticName)")
        } catch {
            loadSummary = "Load failed: \(error.localizedDescription)"
            LabLog.event("Stage41 ViewModel load failed: \(error.localizedDescription)")
        }
    }
}

@MainActor
@Observable
final class Stage41CatalogFeatureModel {
    var query = ""
    var favoriteIDs: Set<CatalogItem.ID> = ["identity"]
    var loadSummary = "Not loaded"
    var loadCount = 0

    init() {
        LabLog.event("Stage41CatalogFeatureModel init")
    }

    deinit {
        LabLog.event("Stage41CatalogFeatureModel deinit")
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
            loadSummary = "Loaded \(items.count) item(s) via feature model"
            LabLog.event("Stage41 feature model load from \(repository.diagnosticName)")
        } catch {
            loadSummary = "Load failed: \(error.localizedDescription)"
            LabLog.event("Stage41 feature model load failed: \(error.localizedDescription)")
        }
    }
}

private struct Stage41ComparisonSummaryCard: View {
    @Binding var localNote: String
    let viewModel: Stage41CatalogViewModel
    let featureModel: Stage41CatalogFeatureModel
    let repositoryName: String
    let onResetViewModel: () -> Void
    let onResetFeatureModel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ownership inventory")
                .font(.headline)

            TextField("Local note (@State)", text: $localNote)
                .textFieldStyle(.roundedBorder)

            Text("Repository dependency: \(repositoryName)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("ViewModel: query='\(viewModel.query)', favorites=\(viewModel.favoriteIDs.count), loads=\(viewModel.loadCount)")
                .font(.caption)
            Text("Feature model: query='\(featureModel.query)', favorites=\(featureModel.favoriteIDs.count), loads=\(featureModel.loadCount)")
                .font(.caption)

            HStack {
                Button("Reset ViewModel") {
                    onResetViewModel()
                }

                Button("Reset feature model") {
                    onResetFeatureModel()
                }
            }

            Text("Resetting one side should only affect that owner. localNote is independent view-local state.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct Stage41MVVMCard: View {
    let viewModel: Stage41CatalogViewModel
    let repository: any ItemRepository

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(alignment: .leading, spacing: 8) {
            Text("Explicit ViewModel")
                .font(.headline)

            TextField("ViewModel query", text: $viewModel.query)
                .textFieldStyle(.roundedBorder)

            Button("Load via ViewModel") {
                let repository = repository
                Task {
                    await viewModel.load(using: repository)
                }
            }

            Text(viewModel.loadSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(viewModel.filteredItems) { item in
                Stage41FavoriteRow(
                    item: item,
                    isFavorite: viewModel.favoriteIDs.contains(item.id),
                    onToggle: { viewModel.toggleFavorite(item.id) }
                )
            }

            Text("Useful when it adds real orchestration or adaptation, not just mirrored fields.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct Stage41FeatureModelCard: View {
    let model: Stage41CatalogFeatureModel
    let repository: any ItemRepository

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 8) {
            Text("Feature model without ViewModel")
                .font(.headline)

            TextField("Feature query", text: $model.query)
                .textFieldStyle(.roundedBorder)

            Button("Load via feature model") {
                let repository = repository
                Task {
                    await model.load(using: repository)
                }
            }

            Text(model.loadSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(model.filteredItems) { item in
                Stage41FavoriteRow(
                    item: item,
                    isFavorite: model.favoriteIDs.contains(item.id),
                    onToggle: { model.toggleFavorite(item.id) }
                )
            }

            Text("Often sufficient for SwiftUI features where state and behavior already map cleanly to one observable owner.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct Stage41FavoriteRow: View {
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

#Preview("Stage 41 - default") {
    Stage41MVVMCriticallyEvaluatedView()
        .environment(AppRouter())
        .environment(AppUIState())
        .environment(Session())
        .environment(\.itemRepository, PreviewItemRepository(name: "Stage 41 preview"))
}

#Preview("Stage 41 - signed out") {
    Stage41MVVMCriticallyEvaluatedView()
        .environment(AppRouter())
        .environment(AppUIState())
        .environment(Session(profile: nil))
        .environment(\.itemRepository, TestItemRepository(name: "Stage 41 test"))
}
