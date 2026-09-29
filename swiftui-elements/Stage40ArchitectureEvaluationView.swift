import Observation
import SwiftUI

@MainActor
struct Stage40ArchitectureEvaluationView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppUIState.self) private var appUIState
    @Environment(Session.self) private var session
    @Environment(\.itemRepository) private var itemRepository

    @State private var model: Stage40ArchitectureLabModel
    @State private var localDraft = "Should this value outlive this screen?"
    @State private var selectedLens: Stage40ReviewLens = .ownership

    init() {
        _model = State(initialValue: Stage40ArchitectureLabModel())
    }

    init(model: Stage40ArchitectureLabModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Stage 40 - Architecture evaluation") {
                    Text("Concept")
                        .font(.headline)
                    Text("After many stages, the useful architecture is the one that fell out of ownership, lifetime, navigation, and dependency decisions. Stage 40 reviews those decisions before introducing a named pattern.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Problem")
                        .font(.headline)
                    Text("As a codebase grows, it is easy to force every feature into MVVM, a coordinator tree, or one giant app model even when the actual responsibilities are smaller and more specific.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Prediction")
                        .font(.headline)
                    Text("Before running: which values should survive recreating the feature model, and which values should only live as long as this one screen?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Implementation") {
                    Stage40ArchitectureLensPanel(selectedLens: $selectedLens)

                    Stage40ArchitectureInventoryPanel(
                        rows: inventoryRows,
                        lens: selectedLens,
                        overlapSummary: overlapSummary
                    )

                    Stage40OwnershipExperimentPanel(
                        model: model,
                        localDraft: $localDraft,
                        repository: itemRepository,
                        onRecreateModel: {
                            model = Stage40ArchitectureLabModel()
                        }
                    )

                    Stage40ShellStatePanel(model: model)
                }

                Section("Run") {
                    Text("1) Type into the local draft field and the feature query field.")
                    Text("2) Tap 'Recreate feature model' and compare what reset versus what survived.")
                    Text("3) Tap the shell-state buttons to mutate Session, AppRouter, and AppUIState, then compare their current values in the inventory panel.")
                    Text("4) Trigger 'Load through repository' and watch the console logs to see dependency usage without adding a dedicated ViewModel layer.")
                }

                Section("Explanation") {
                    Text("The root app currently owns shell-level state and dependencies: session identity, routing, a smaller UI-state object, and the repository service. That is app composition, not a monolithic app model.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Feature models earn their existence when a feature needs cohesive mutable behavior across multiple subviews or async work. Simple single-view toggles, draft text, and temporary selections usually stay as plain @State.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("This project also shows a transitional overlap: both AppRouter and AppUIState carry shell concerns. That is acceptable during a course sequence, but it is exactly the kind of duplication Stage 40 should surface before a larger refactor.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Refactor") {
                    Text("The next architectural cleanup would be organizational rather than ideological: group app-scope types under an App area, feature models under Feature areas, shared services under Services, and reusable visual pieces under UI Components.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Only consolidate AppRouter and AppUIState when the overlap becomes a real maintenance cost. Stage 40 is about seeing the boundary clearly before merging it blindly.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Takeaway") {
                    Text("- Start from ownership and lifetime, not from a pattern name.")
                    Text("- Keep app-scope state small and intentional.")
                    Text("- Use a feature model when multiple views or async behavior need one cohesive owner.")
                    Text("- Keep ephemeral single-view state as plain @State until it proves otherwise.")
                }
            }
            .navigationTitle("Architecture Review")
        }
        .onAppear {
            LabLog.event("Stage40ArchitectureEvaluationView onAppear")
        }
    }

    private var inventoryRows: [Stage40ArchitectureRow] {
        [
            Stage40ArchitectureRow(
                name: "swiftui_elementsApp",
                owner: "App entry point",
                lifetime: "App / scene",
                currentValue: "Owns AppRouter, AppUIState, Session, LiveItemRepository",
                reason: "Root composition and dependency injection belong at the app boundary."
            ),
            Stage40ArchitectureRow(
                name: "AppRouter",
                owner: "App root via @State",
                lifetime: "App / scene",
                currentValue: "selectedTab=\(router.selectedTab.rawValue), catalogPath=\(router.catalogPath.count), searchPath=\(router.searchPath.count)",
                reason: "Shell navigation is app-scoped because deep links, tab switches, and cross-feature jumps may need it."
            ),
            Stage40ArchitectureRow(
                name: "AppUIState",
                owner: "App root via @State",
                lifetime: "App / scene",
                currentValue: "selectedTab=\(appUIState.selectedTab.rawValue), catalogPath=\(appUIState.catalogPath.count), sheet=\(appUIState.presentedSheet?.rawValue ?? "none")",
                reason: "Presentation and shell UI state can live at app scope, but this file also reveals overlap with AppRouter."
            ),
            Stage40ArchitectureRow(
                name: "Session",
                owner: "App root via @State",
                lifetime: "App / scene",
                currentValue: session.profile?.displayName ?? "signed out",
                reason: "Authentication identity is application-wide because many features may depend on it."
            ),
            Stage40ArchitectureRow(
                name: "Stage40ArchitectureLabModel",
                owner: "This feature view via @State",
                lifetime: "Feature",
                currentValue: "query='\(model.featureQuery)', favorites=\(model.favoriteIDs.count), loads=\(model.loadCount)",
                reason: "A feature model is justified here because several subviews coordinate mutable feature state and async loading."
            ),
            Stage40ArchitectureRow(
                name: "localDraft + selectedLens",
                owner: "This view via @State",
                lifetime: "View",
                currentValue: "draftLength=\(localDraft.count), lens=\(selectedLens.rawValue)",
                reason: "These values are local UI concerns and do not need their own reference model."
            ),
            Stage40ArchitectureRow(
                name: "itemRepository",
                owner: "Injected environment dependency",
                lifetime: "App / preview override",
                currentValue: itemRepository.diagnosticName,
                reason: "Services are dependencies, not view state. The environment distributes access without making the service itself app state."
            )
        ]
    }

    private var overlapSummary: String {
        let isAligned = router.selectedTab == appUIState.selectedTab && router.catalogPath.count == appUIState.catalogPath.count
        return isAligned
            ? "Right now AppRouter and AppUIState happen to agree on selected tab and catalog path count."
            : "AppRouter and AppUIState currently disagree. That is a useful sign that these are separate owners with overlapping responsibilities."
    }
}

@MainActor
@Observable
final class Stage40ArchitectureLabModel {
    var featureQuery = "state"
    var favoriteIDs: Set<CatalogItem.ID> = ["identity"]
    var loadCount = 0
    var loadSummary = "Nothing loaded yet"

    init() {
        LabLog.event("Stage40ArchitectureLabModel init")
    }

    deinit {
        LabLog.event("Stage40ArchitectureLabModel deinit")
    }

    var filteredItems: [CatalogItem] {
        guard !featureQuery.isEmpty else { return CatalogItem.samples }

        return CatalogItem.samples.filter { item in
            item.title.localizedCaseInsensitiveContains(featureQuery)
            || item.subtitle.localizedCaseInsensitiveContains(featureQuery)
        }
    }

    func toggleFavorite(_ itemID: CatalogItem.ID) {
        if favoriteIDs.contains(itemID) {
            favoriteIDs.remove(itemID)
        } else {
            favoriteIDs.insert(itemID)
        }

        LabLog.event("Stage40 toggled favorite for \(itemID)")
    }

    func load(using repository: any ItemRepository) async {
        do {
            let items = try await repository.featuredItems()
            loadCount += 1
            loadSummary = "Loaded \(items.count) item(s) from \(repository.diagnosticName)"
            LabLog.event("Stage40 loaded \(items.count) item(s) from \(repository.diagnosticName)")
        } catch {
            loadSummary = "Failed via \(repository.diagnosticName): \(error.localizedDescription)"
            LabLog.event("Stage40 failed via \(repository.diagnosticName): \(error.localizedDescription)")
        }
    }
}

private struct Stage40ArchitectureLensPanel: View {
    @Binding var selectedLens: Stage40ReviewLens

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review lens")
                .font(.headline)

            Picker("Review lens", selection: $selectedLens) {
                ForEach(Stage40ReviewLens.allCases) { lens in
                    Text(lens.title).tag(lens)
                }
            }
            .pickerStyle(.segmented)

            Text(selectedLens.prompt)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct Stage40ArchitectureInventoryPanel: View {
    let rows: [Stage40ArchitectureRow]
    let lens: Stage40ReviewLens
    let overlapSummary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current architecture inventory")
                .font(.headline)

            Text(overlapSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.name)
                            .font(.subheadline.bold())
                        Spacer()
                        Text(row.lifetime)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("Owner: \(row.owner)")
                        .font(.caption)
                    Text("Current value: \(row.currentValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(lens.rowLabel + row.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if row.id != rows.last?.id {
                    Divider()
                }
            }
        }
        .stageCard()
    }
}

private struct Stage40OwnershipExperimentPanel: View {
    let model: Stage40ArchitectureLabModel
    @Binding var localDraft: String
    let repository: any ItemRepository
    let onRecreateModel: () -> Void

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 12) {
            Text("Plain @State versus feature model")
                .font(.headline)

            TextField("Local draft question", text: $localDraft)
                .textFieldStyle(.roundedBorder)

            TextField("Feature query", text: $model.featureQuery)
                .textFieldStyle(.roundedBorder)

            Button("Load through repository") {
                let repository = repository
                Task {
                    await model.load(using: repository)
                }
            }

            Text(model.loadSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(model.filteredItems) { item in
                Button {
                    model.toggleFavorite(item.id)
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
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Button("Recreate feature model") {
                onRecreateModel()
            }

            Text("The local draft is plain view state. The query, favorites, and async summary live together in a feature model because multiple controls coordinate them.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct Stage40ShellStatePanel: View {
    let model: Stage40ArchitectureLabModel

    @Environment(AppRouter.self) private var router
    @Environment(AppUIState.self) private var appUIState
    @Environment(Session.self) private var session

    var body: some View {
        @Bindable var router = router
        @Bindable var appUIState = appUIState

        VStack(alignment: .leading, spacing: 12) {
            Text("Shell-level state")
                .font(.headline)

            Picker("Router selected tab", selection: $router.selectedTab) {
                ForEach(AppTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            Picker("App UI selected tab", selection: $appUIState.selectedTab) {
                ForEach(AppTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button("Append router route") {
                    router.openCatalogItem("identity", source: "Stage 40")
                }

                Button("Append UI route") {
                    appUIState.openFirstItem(from: CatalogItem.samples)
                }
            }

            HStack {
                Button("Logout") {
                    session.signOut()
                    router.resetForLogout()
                    appUIState.resetForLogout()
                    model.featureQuery = ""
                }

                Button("Sign in sample") {
                    session.signInSampleUser()
                }
            }

            Text("Use this panel to inspect what truly belongs to the shell. The overlap between router and app UI state is visible because both can be mutated independently.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct Stage40ArchitectureRow: Identifiable {
    let name: String
    let owner: String
    let lifetime: String
    let currentValue: String
    let reason: String

    var id: String { name }
}

private enum Stage40ReviewLens: String, CaseIterable, Identifiable {
    case ownership = "Ownership"
    case lifetime = "Lifetime"
    case dependencies = "Dependencies"
    case testability = "Testability"

    var id: Self { self }

    var title: String { rawValue }

    var prompt: String {
        switch self {
        case .ownership:
            return "Ask who creates each type, who keeps it alive, and whether that owner matches the feature boundary."
        case .lifetime:
            return "Ask whether each value should survive a body recomputation, a feature reset, logout, or process termination."
        case .dependencies:
            return "Ask whether a value is true state, a derived projection, or just a dependency being accessed through the environment."
        case .testability:
            return "Ask which behavior can be tested without rendering SwiftUI, and which pieces are intentionally just lightweight view glue."
        }
    }

    var rowLabel: String {
        switch self {
        case .ownership:
            return "Ownership review: "
        case .lifetime:
            return "Lifetime review: "
        case .dependencies:
            return "Dependency review: "
        case .testability:
            return "Testability review: "
        }
    }
}

#Preview("Stage 40 - default") {
    Stage40ArchitectureEvaluationView()
        .environment(AppRouter())
        .environment(AppUIState())
        .environment(Session())
        .environment(\.itemRepository, PreviewItemRepository(name: "Stage 40 preview"))
}

#Preview("Stage 40 - signed out") {
    Stage40ArchitectureEvaluationView(model: Stage40ArchitectureLabModel())
        .environment(AppRouter())
        .environment(AppUIState())
        .environment(Session(profile: nil))
        .environment(\.itemRepository, TestItemRepository(name: "Stage 40 test repository"))
}
