import SwiftUI

@MainActor
struct ContentView: View {
    @State private var parentRevision = 0
    @State private var appUIState = AppUIState()
    @State private var catalogModel = CatalogFeatureModel()
    @State private var session = Session()
    @State private var persistedLaunchCount = 1

    init() {
        LabLog.event("ContentView init")
    }

    var body: some View {
        let _ = LabLog.event("ContentView body")

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Stage 6: Environment + Dependency Injection")
                    .font(.title.bold())

                Text("Stage 5 separated state from services. Stage 6 now changes how services are provided: child views resolve dependencies from the SwiftUI environment instead of receiving every service through initializer plumbing.")
                    .foregroundStyle(.secondary)

                Divider()

                parentControls
                environmentQuestionCard

                DependencyInjectionInventoryView(
                    appUIState: appUIState,
                    catalogModel: catalogModel,
                    session: session,
                    persistedLaunchCount: persistedLaunchCount
                )

                SearchAndNavigationPanel(appUIState: appUIState, catalogModel: catalogModel)
                CatalogFeaturePanel(model: catalogModel)
                ProfilePanel(session: session, appUIState: appUIState, catalogModel: catalogModel)

                RepositoryAccessPanel(
                    title: "Repository resolved from app root",
                    explanation: "This panel does not receive a repository in its initializer. It reads the ItemRepository dependency from @Environment, where the app root injects the live implementation."
                )

                FeatureOverrideDemoView()
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

            Button("Reset app UI state only") {
                appUIState.resetTransientState()
            }

            Button("Recreate catalog feature model") {
                catalogModel = CatalogFeatureModel()
                LabLog.event("ContentView recreated CatalogFeatureModel")
            }

            Text("The repository dependency is not reset by these controls because it is not owned by ContentView's feature state. It is supplied by the environment from a higher composition boundary.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var environmentQuestionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prediction")
                .font(.headline)

            Text("Before pressing the repository buttons, predict which implementation each panel will resolve: the app-root live repository or the feature-level preview override.")

            Text("Environment values flow downward. A closer override wins for that subtree, but sibling views keep using the value from their own environment chain.")
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

@Observable
private final class AppUIState {
    var selectedTab: AppTab = .catalog
    var catalogPath: [CatalogItem.ID] = []
    var isShowingSettingsSheet = false

    init() {
        LabLog.event("AppUIState init")
    }

    deinit {
        LabLog.event("AppUIState deinit")
    }

    func openFirstItem(from items: [CatalogItem]) {
        guard let firstItem = items.first else { return }
        catalogPath.append(firstItem.id)
        LabLog.event("AppUIState appended \(firstItem.id) to catalogPath")
    }

    func resetTransientState() {
        selectedTab = .catalog
        catalogPath.removeAll()
        isShowingSettingsSheet = false
        LabLog.event("AppUIState reset selected tab, path, and sheet state")
    }
}

@Observable
private final class CatalogFeatureModel {
    var searchText = ""
    var items: [CatalogItem]
    var favoriteIDs: Set<CatalogItem.ID>

    init(
        items: [CatalogItem] = CatalogItem.samples,
        favoriteIDs: Set<CatalogItem.ID> = [CatalogItem.samples[0].id]
    ) {
        self.items = items
        self.favoriteIDs = favoriteIDs
        LabLog.event("CatalogFeatureModel init")
    }

    deinit {
        LabLog.event("CatalogFeatureModel deinit")
    }

    func toggleFavorite(_ item: CatalogItem) {
        if favoriteIDs.contains(item.id) {
            favoriteIDs.remove(item.id)
        } else {
            favoriteIDs.insert(item.id)
        }

        LabLog.event("CatalogFeatureModel toggled favorite for \(item.title)")
    }

    func clearUserScopedState() {
        searchText = ""
        favoriteIDs.removeAll()
        LabLog.event("CatalogFeatureModel cleared search text and favorites")
    }
}

@Observable
private final class Session {
    var profile: UserProfile?

    init(profile: UserProfile? = .sample) {
        self.profile = profile
        LabLog.event("Session init")
    }

    deinit {
        LabLog.event("Session deinit")
    }

    func signOut() {
        profile = nil
        LabLog.event("Session signed out")
    }
}

protocol ItemRepository {
    var diagnosticName: String { get }
    func featuredItems() async throws -> [CatalogItem]
}

final class LiveItemRepository: ItemRepository {
    private let networkClient: NetworkClient
    private let database: Database

    init() {
        self.networkClient = NetworkClient(name: "Live API")
        self.database = Database(name: "Catalog.sqlite")
        LabLog.event("LiveItemRepository init")
    }

    deinit {
        LabLog.event("LiveItemRepository deinit")
    }

    var diagnosticName: String {
        "LiveItemRepository(network: \(networkClient.name), database: \(database.name))"
    }

    func featuredItems() async throws -> [CatalogItem] {
        LabLog.event("LiveItemRepository featuredItems using \(networkClient.name) + \(database.name)")
        return CatalogItem.samples
    }
}

struct PreviewItemRepository: ItemRepository {
    let diagnosticName: String
    private let items: [CatalogItem]

    init(name: String = "PreviewItemRepository", items: [CatalogItem] = CatalogItem.samples) {
        self.diagnosticName = name
        self.items = items
        LabLog.event("PreviewItemRepository init: \(name)")
    }

    func featuredItems() async throws -> [CatalogItem] {
        LabLog.event("PreviewItemRepository featuredItems: \(diagnosticName)")
        return items
    }
}

struct TestItemRepository: ItemRepository {
    let diagnosticName: String
    private let result: Result<[CatalogItem], Error>

    init(
        name: String = "TestItemRepository",
        result: Result<[CatalogItem], Error> = .success(CatalogItem.samples)
    ) {
        self.diagnosticName = name
        self.result = result
    }

    func featuredItems() async throws -> [CatalogItem] {
        LabLog.event("TestItemRepository featuredItems: \(diagnosticName)")
        return try result.get()
    }
}

private struct ItemRepositoryEnvironmentKey: EnvironmentKey {
    static let defaultValue: any ItemRepository = PreviewItemRepository(name: "Default fallback repository")
}

extension EnvironmentValues {
    var itemRepository: any ItemRepository {
        get { self[ItemRepositoryEnvironmentKey.self] }
        set { self[ItemRepositoryEnvironmentKey.self] = newValue }
    }
}

private enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home = "Home"
    case catalog = "Catalog"
    case favorites = "Favorites"
    case profile = "Profile"

    var id: Self { self }
}

struct CatalogItem: Identifiable, Equatable {
    let id: String
    var title: String
    var subtitle: String

    static let samples = [
        CatalogItem(id: "identity", title: "Identity", subtitle: "What is the same view over time?"),
        CatalogItem(id: "state", title: "State", subtitle: "Who owns the source of truth?"),
        CatalogItem(id: "observation", title: "Observation", subtitle: "Which property did this body read?")
    ]

    static let previewOverrideSamples = [
        CatalogItem(id: "preview-a", title: "Preview A", subtitle: "Supplied by a closer environment override"),
        CatalogItem(id: "preview-b", title: "Preview B", subtitle: "Sibling views do not see this repository")
    ]
}

private struct UserProfile: Equatable {
    var displayName: String
    var isSignedIn: Bool

    static let sample = UserProfile(displayName: "Mauro", isSignedIn: true)
}

private final class NetworkClient {
    let name: String

    init(name: String) {
        self.name = name
        LabLog.event("NetworkClient init: \(name)")
    }

    deinit {
        LabLog.event("NetworkClient deinit: \(name)")
    }
}

private final class Database {
    let name: String

    init(name: String) {
        self.name = name
        LabLog.event("Database init: \(name)")
    }

    deinit {
        LabLog.event("Database deinit: \(name)")
    }
}

private struct DependencyInjectionInventoryView: View {
    let appUIState: AppUIState
    let catalogModel: CatalogFeatureModel
    let session: Session
    let persistedLaunchCount: Int

    @Environment(\.itemRepository) private var itemRepository

    init(
        appUIState: AppUIState,
        catalogModel: CatalogFeatureModel,
        session: Session,
        persistedLaunchCount: Int
    ) {
        self.appUIState = appUIState
        self.catalogModel = catalogModel
        self.session = session
        self.persistedLaunchCount = persistedLaunchCount
        LabLog.event("DependencyInjectionInventoryView init")
    }

    var body: some View {
        let _ = LabLog.event("DependencyInjectionInventoryView body")

        VStack(alignment: .leading, spacing: 12) {
            Text("State is passed explicitly; services come from context")
                .font(.headline)

            StateCategoryRow(owner: "AppUIState", name: "selectedTab", currentValue: appUIState.selectedTab.rawValue, category: "Application UI state")
            StateCategoryRow(owner: "AppUIState", name: "catalogPath", currentValue: "\(appUIState.catalogPath.count) route value(s)", category: "Navigation-like state")
            StateCategoryRow(owner: "AppUIState", name: "isShowingSettingsSheet", currentValue: appUIState.isShowingSettingsSheet ? "true" : "false", category: "Presentation state")
            StateCategoryRow(owner: "CatalogFeatureModel", name: "searchText", currentValue: catalogModel.searchText.isEmpty ? "empty" : catalogModel.searchText, category: "Feature UI state")
            StateCategoryRow(owner: "CatalogFeatureModel", name: "items", currentValue: "\(catalogModel.items.count) item(s)", category: "Domain/cache state")
            StateCategoryRow(owner: "CatalogFeatureModel", name: "favoriteIDs", currentValue: "\(catalogModel.favoriteIDs.count) favorite(s)", category: "Feature/domain state")
            StateCategoryRow(owner: "Session", name: "profile", currentValue: session.profile?.displayName ?? "signed out", category: "Session/domain state")
            StateCategoryRow(owner: "Environment", name: "itemRepository", currentValue: itemRepository.diagnosticName, category: "Service/dependency")
            StateCategoryRow(owner: "ContentView @State", name: "persistedLaunchCount", currentValue: "\(persistedLaunchCount)", category: "Persistent-state placeholder")

            Text("Notice the asymmetry: feature state is still explicit because ownership matters, while the repository is contextual because many descendants may need the same service dependency.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct StateCategoryRow: View {
    let owner: String
    let name: String
    let currentValue: String
    let category: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(owner).\(name)")
                    .font(.subheadline.bold())

                Spacer()

                Text(category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(currentValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct SearchAndNavigationPanel: View {
    @Bindable var appUIState: AppUIState
    @Bindable var catalogModel: CatalogFeatureModel

    init(appUIState: AppUIState, catalogModel: CatalogFeatureModel) {
        self.appUIState = appUIState
        self.catalogModel = catalogModel
        LabLog.event("SearchAndNavigationPanel init")
    }

    var body: some View {
        let _ = LabLog.event("SearchAndNavigationPanel body")

        VStack(alignment: .leading, spacing: 12) {
            Text("Initializer injection for owned state")
                .font(.headline)

            Picker("Selected tab", selection: $appUIState.selectedTab) {
                ForEach(AppTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            TextField("Catalog search text", text: $catalogModel.searchText)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Append item route") {
                    appUIState.openFirstItem(from: catalogModel.items)
                }

                Button("Clear path") {
                    appUIState.catalogPath.removeAll()
                    LabLog.event("AppUIState cleared catalogPath")
                }
            }

            Text("Path count: \(appUIState.catalogPath.count)")

            Toggle("Pretend settings sheet is presented", isOn: $appUIState.isShowingSettingsSheet)

            Text("These observable state owners are still initializer-injected because this view directly edits them. Environment injection would make ownership less obvious here, not clearer.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct CatalogFeaturePanel: View {
    let model: CatalogFeatureModel

    init(model: CatalogFeatureModel) {
        self.model = model
        LabLog.event("CatalogFeaturePanel init")
    }

    var body: some View {
        let _ = LabLog.event("CatalogFeaturePanel body")

        VStack(alignment: .leading, spacing: 12) {
            Text("Catalog feature state")
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

            Text("CatalogFeatureModel still owns catalog-specific mutable state. The repository dependency can be accessed by subviews that need data loading without forcing this panel to receive or forward it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct ProfilePanel: View {
    let session: Session
    let appUIState: AppUIState
    let catalogModel: CatalogFeatureModel

    init(session: Session, appUIState: AppUIState, catalogModel: CatalogFeatureModel) {
        self.session = session
        self.appUIState = appUIState
        self.catalogModel = catalogModel
        LabLog.event("ProfilePanel init")
    }

    var body: some View {
        let _ = LabLog.event("ProfilePanel body")

        VStack(alignment: .leading, spacing: 8) {
            Text("Session/domain state")
                .font(.headline)

            Label(session.profile?.displayName ?? "Guest", systemImage: session.profile == nil ? "person.crop.circle" : "person.crop.circle.fill")

            Text(session.profile == nil ? "Signed out" : "Signed in")
                .foregroundStyle(.secondary)

            Button("Logout with explicit reset policy") {
                session.signOut()
                appUIState.resetTransientState()
                catalogModel.clearUserScopedState()
            }

            Text("Logout still mutates explicit state owners. The repository dependency is not signed out here; a real app might instead give the repository an auth provider or rebuild a session-scoped dependency container at the composition boundary.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct RepositoryAccessPanel: View {
    let title: String
    let explanation: String

    @Environment(\.itemRepository) private var itemRepository
    @State private var loadSummary = "Not loaded yet"

    init(title: String, explanation: String) {
        self.title = title
        self.explanation = explanation
        LabLog.event("RepositoryAccessPanel init: \(title)")
    }

    var body: some View {
        let _ = LabLog.event("RepositoryAccessPanel body: \(title)")

        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text("Resolved dependency:")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(itemRepository.diagnosticName)
                .font(.subheadline.monospaced())

            Button("Fetch featured items through environment") {
                let repository = itemRepository

                Task {
                    do {
                        let items = try await repository.featuredItems()
                        loadSummary = "Loaded \(items.count) item(s): \(items.map(\.title).joined(separator: ", "))"
                        LabLog.event("RepositoryAccessPanel loaded via \(repository.diagnosticName)")
                    } catch {
                        loadSummary = "Failed: \(error.localizedDescription)"
                        LabLog.event("RepositoryAccessPanel failed via \(repository.diagnosticName): \(error.localizedDescription)")
                    }
                }
            }

            Text(loadSummary)
                .font(.caption)

            Text(explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct FeatureOverrideDemoView: View {
    init() {
        LabLog.event("FeatureOverrideDemoView init")
    }

    var body: some View {
        let _ = LabLog.event("FeatureOverrideDemoView body")

        VStack(alignment: .leading, spacing: 12) {
            Text("Feature-level environment override")
                .font(.headline)

            Text("The parent app injects a live repository. This subtree overrides only itemRepository with a preview repository. This is the same mechanism previews, tests, and isolated features can use.")
                .font(.caption)
                .foregroundStyle(.secondary)

            RepositoryAccessPanel(
                title: "Repository resolved from closer override",
                explanation: "Only this subtree sees the preview repository. Views above or beside it keep resolving the app-root repository."
            )
            .environment(
                \.itemRepository,
                PreviewItemRepository(
                    name: "Feature override preview repository",
                    items: CatalogItem.previewOverrideSamples
                )
            )
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

enum LabLog {
    nonisolated static func event(_ message: String) {
        print("🧪 \(message)")
    }
}

#Preview("App-root preview dependency") {
    ContentView()
        .environment(\.itemRepository, PreviewItemRepository())
}

#Preview("Test dependency") {
    ContentView()
        .environment(\.itemRepository, TestItemRepository())
}
