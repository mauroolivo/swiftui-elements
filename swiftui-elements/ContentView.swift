import SwiftUI

@MainActor
struct ContentView: View {
    @State private var contentRevision = 0
    @State private var catalogModel = CatalogFeatureModel()

    init() {
        LabLog.event("ContentView init")
    }

    var body: some View {
        let _ = LabLog.event("ContentView body")

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Stage 7: Application-wide State")
                    .font(.title.bold())

                Text("Stage 6 used environment for services. Stage 7 now adds carefully chosen app-wide observable state: session and app UI state live at the App composition boundary, while catalog feature state stays feature-owned.")
                    .foregroundStyle(.secondary)

                Divider()

                predictionCard

                ApplicationStateInventoryView(
                    catalogModel: catalogModel,
                    contentRevision: contentRevision
                )

                ApplicationStateControls(
                    catalogModel: catalogModel,
                    onRecomputeContentView: {
                        contentRevision += 1
                        LabLog.event("contentRevision changed to \(contentRevision)")
                    },
                    onRecreateCatalogModel: {
                        catalogModel = CatalogFeatureModel()
                        LabLog.event("ContentView recreated CatalogFeatureModel")
                    }
                )

                SearchAndNavigationPanel(catalogModel: catalogModel)
                CatalogFeaturePanel(model: catalogModel)
                ProfilePanel(catalogModel: catalogModel)

                RepositoryAccessPanel(
                    title: "Repository still comes from dependency environment",
                    explanation: "This is Stage 6's service dependency. It is not app-wide mutable UI state; it is contextual infrastructure supplied by the app root."
                )

                AppWideStateOverrideDemoView()
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

    private var predictionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prediction")
                .font(.headline)

            Text("Before using the controls, predict which lifetime each value has: app, feature, view, or dependency.")

            Text("Changing selectedTab or signing out should mutate app-wide state. Recreating the catalog feature model should not replace Session, AppUIState, or ItemRepository.")
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

@Observable
final class AppUIState {
    var selectedTab: AppTab = .catalog
    var catalogPath: [CatalogRoute] = []
    var presentedSheet: AppSheet?

    init() {
        LabLog.event("AppUIState init")
    }

    deinit {
        LabLog.event("AppUIState deinit")
    }

    func openFirstItem(from items: [CatalogItem]) {
        guard let firstItem = items.first else { return }
        catalogPath.append(.item(firstItem.id))
        LabLog.event("AppUIState appended route for \(firstItem.id)")
    }

    func resetTransientState() {
        selectedTab = .catalog
        catalogPath.removeAll()
        presentedSheet = nil
        LabLog.event("AppUIState reset selected tab, path, and sheet state")
    }

    func resetForLogout() {
        selectedTab = .home
        catalogPath.removeAll()
        presentedSheet = nil
        LabLog.event("AppUIState reset app navigation and presentation for logout")
    }
}

@Observable
final class Session {
    var profile: UserProfile?

    init(profile: UserProfile? = .sample) {
        self.profile = profile
        LabLog.event("Session init")
    }

    deinit {
        LabLog.event("Session deinit")
    }

    func signInSampleUser() {
        profile = .sample
        LabLog.event("Session signed in sample user")
    }

    func signOut() {
        profile = nil
        LabLog.event("Session signed out")
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

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home = "Home"
    case catalog = "Catalog"
    case favorites = "Favorites"
    case profile = "Profile"

    var id: Self { self }
}

enum CatalogRoute: Hashable {
    case item(CatalogItem.ID)
}

enum AppSheet: String, Identifiable, Hashable {
    case settings

    var id: Self { self }
}

struct CatalogItem: Identifiable, Equatable, Hashable {
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

struct UserProfile: Equatable, Hashable {
    var displayName: String
    var isSignedIn: Bool

    static let sample = UserProfile(displayName: "Mauro", isSignedIn: true)
    static let preview = UserProfile(displayName: "Preview User", isSignedIn: true)
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

private struct ApplicationStateInventoryView: View {
    let catalogModel: CatalogFeatureModel
    let contentRevision: Int

    @Environment(AppUIState.self) private var appUIState
    @Environment(Session.self) private var session
    @Environment(\.itemRepository) private var itemRepository

    init(catalogModel: CatalogFeatureModel, contentRevision: Int) {
        self.catalogModel = catalogModel
        self.contentRevision = contentRevision
        LabLog.event("ApplicationStateInventoryView init")
    }

    var body: some View {
        let _ = LabLog.event("ApplicationStateInventoryView body")

        VStack(alignment: .leading, spacing: 12) {
            Text("Application scope is intentionally small")
                .font(.headline)

            StateCategoryRow(owner: "App @State → Environment", name: "Session.profile", currentValue: session.profile?.displayName ?? "signed out", category: "Application/session state")
            StateCategoryRow(owner: "App @State → Environment", name: "AppUIState.selectedTab", currentValue: appUIState.selectedTab.rawValue, category: "Application UI state")
            StateCategoryRow(owner: "App @State → Environment", name: "AppUIState.catalogPath", currentValue: "\(appUIState.catalogPath.count) route value(s)", category: "Navigation state placeholder")
            StateCategoryRow(owner: "App @State → Environment", name: "AppUIState.presentedSheet", currentValue: appUIState.presentedSheet?.rawValue ?? "none", category: "Presentation state placeholder")
            StateCategoryRow(owner: "ContentView @State", name: "CatalogFeatureModel.searchText", currentValue: catalogModel.searchText.isEmpty ? "empty" : catalogModel.searchText, category: "Feature UI state")
            StateCategoryRow(owner: "ContentView @State", name: "CatalogFeatureModel.items", currentValue: "\(catalogModel.items.count) item(s)", category: "Feature/domain cache")
            StateCategoryRow(owner: "ContentView @State", name: "CatalogFeatureModel.favoriteIDs", currentValue: "\(catalogModel.favoriteIDs.count) favorite(s)", category: "User-scoped feature state")
            StateCategoryRow(owner: "Environment", name: "ItemRepository", currentValue: itemRepository.diagnosticName, category: "Service dependency")
            StateCategoryRow(owner: "ContentView @State", name: "contentRevision", currentValue: "\(contentRevision)", category: "Local lab view state")

            Text("The app root now owns app-wide state. CatalogFeatureModel deliberately did not move there: a global AppState should not absorb every feature's mutable details.")
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

private struct ApplicationStateControls: View {
    let catalogModel: CatalogFeatureModel
    let onRecomputeContentView: () -> Void
    let onRecreateCatalogModel: () -> Void

    @Environment(AppUIState.self) private var appUIState
    @Environment(Session.self) private var session

    init(
        catalogModel: CatalogFeatureModel,
        onRecomputeContentView: @escaping () -> Void,
        onRecreateCatalogModel: @escaping () -> Void
    ) {
        self.catalogModel = catalogModel
        self.onRecomputeContentView = onRecomputeContentView
        self.onRecreateCatalogModel = onRecreateCatalogModel
        LabLog.event("ApplicationStateControls init")
    }

    var body: some View {
        let _ = LabLog.event("ApplicationStateControls body")

        VStack(alignment: .leading, spacing: 8) {
            Text("Lifetime controls")
                .font(.headline)

            Button("Recompute ContentView") {
                onRecomputeContentView()
            }

            Button("Recreate catalog feature model") {
                onRecreateCatalogModel()
            }

            Button("Reset app UI state only") {
                appUIState.resetTransientState()
            }

            Button("Sign sample user back in") {
                session.signInSampleUser()
            }

            Button("Logout with explicit app + feature reset policy") {
                session.signOut()
                appUIState.resetForLogout()
                catalogModel.clearUserScopedState()
            }

            Text("Recreating feature state should not recreate Session, AppUIState, or ItemRepository. Logout is explicit: app/session state resets at app scope, while user-scoped catalog state resets at the feature boundary.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct SearchAndNavigationPanel: View {
    let catalogModel: CatalogFeatureModel

    @Environment(AppUIState.self) private var appUIState

    init(catalogModel: CatalogFeatureModel) {
        self.catalogModel = catalogModel
        LabLog.event("SearchAndNavigationPanel init")
    }

    var body: some View {
        let _ = LabLog.event("SearchAndNavigationPanel body")
        @Bindable var editableAppUIState = appUIState
        @Bindable var editableCatalogModel = catalogModel

        VStack(alignment: .leading, spacing: 12) {
            Text("App state + feature state in one UI")
                .font(.headline)

            Picker("Selected tab", selection: $editableAppUIState.selectedTab) {
                ForEach(AppTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            TextField("Catalog search text", text: $editableCatalogModel.searchText)
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

            Toggle("Pretend settings sheet is presented", isOn: Binding(
                get: { appUIState.presentedSheet == .settings },
                set: { isPresented in
                    appUIState.presentedSheet = isPresented ? .settings : nil
                    LabLog.event("AppUIState settings sheet flag changed to \(isPresented)")
                }
            ))

            Text("This view edits app-wide state and feature state, but those values still have different owners and reset rules.")
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
            Text("Feature-owned catalog state")
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

            Text("Favorites are user-scoped feature state in this lab. They are cleared on logout by policy, not because the entire app model was replaced.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct ProfilePanel: View {
    let catalogModel: CatalogFeatureModel

    @Environment(AppUIState.self) private var appUIState
    @Environment(Session.self) private var session

    init(catalogModel: CatalogFeatureModel) {
        self.catalogModel = catalogModel
        LabLog.event("ProfilePanel init")
    }

    var body: some View {
        let _ = LabLog.event("ProfilePanel body")

        VStack(alignment: .leading, spacing: 8) {
            Text("Session as app-wide state")
                .font(.headline)

            Label(session.profile?.displayName ?? "Guest", systemImage: session.profile == nil ? "person.crop.circle" : "person.crop.circle.fill")

            Text(session.profile == nil ? "Signed out" : "Signed in")
                .foregroundStyle(.secondary)

            Button("Logout from profile panel") {
                session.signOut()
                appUIState.resetForLogout()
                catalogModel.clearUserScopedState()
            }

            Text("Session is app-wide because many features may need signed-in identity. That does not mean every feature model should also become app-wide.")
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

private struct AppWideStateOverrideDemoView: View {
    @State private var isolatedSession = Session(profile: .preview)

    init() {
        LabLog.event("AppWideStateOverrideDemoView init")
    }

    var body: some View {
        let _ = LabLog.event("AppWideStateOverrideDemoView body")

        VStack(alignment: .leading, spacing: 12) {
            Text("Scoped override for app-wide state")
                .font(.headline)

            Text("This subtree overrides Session with its own @State-owned instance. This is useful for previews and isolated flows, but it also shows why environment lookup is contextual rather than truly global.")
                .font(.caption)
                .foregroundStyle(.secondary)

            SessionStatusPanel(title: "Root session status before override")

            SessionStatusPanel(title: "Session status inside override")
                .environment(isolatedSession)

            RepositoryAccessPanel(
                title: "Repository override still works independently",
                explanation: "Overriding Session does not override ItemRepository. Environment keys and type-based observable values are independent channels."
            )
            .environment(
                \.itemRepository,
                PreviewItemRepository(
                    name: "Stage 7 subtree preview repository",
                    items: CatalogItem.previewOverrideSamples
                )
            )
        }
        .stageCard()
    }
}

private struct SessionStatusPanel: View {
    let title: String

    @Environment(Session.self) private var session

    init(title: String) {
        self.title = title
        LabLog.event("SessionStatusPanel init: \(title)")
    }

    var body: some View {
        let _ = LabLog.event("SessionStatusPanel body: \(title)")

        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.bold())

            Text("Resolved session: \(session.profile?.displayName ?? "signed out")")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Sign out this session") {
                    session.signOut()
                }

                Button("Sign in sample") {
                    session.signInSampleUser()
                }
            }
            .font(.caption)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
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

#Preview("Stage 7 app state") {
    ContentView()
        .environment(AppUIState())
        .environment(Session())
        .environment(\.itemRepository, PreviewItemRepository())
}

#Preview("Signed out") {
    ContentView()
        .environment(AppUIState())
        .environment(Session(profile: nil))
        .environment(\.itemRepository, TestItemRepository())
}
