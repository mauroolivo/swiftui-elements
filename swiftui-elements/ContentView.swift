import SwiftUI

@MainActor
struct ContentView: View {
    @State private var parentRevision = 0
    @State private var appUIState = AppUIState()
    @State private var catalogModel = CatalogFeatureModel()
    @State private var session = Session()
    @State private var services = AppServices.live()
    @State private var persistedLaunchCount = 1

    init() {
        LabLog.event("ContentView init")
    }

    var body: some View {
        let _ = LabLog.event("ContentView body")

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Stage 5: State vs Model vs Service")
                    .font(.title.bold())

                Text("Exercise B refactors the giant observable object into smaller owners. The goal is not more files or more patterns; it is matching each piece of mutable state to an appropriate owner and lifetime.")
                    .foregroundStyle(.secondary)

                Divider()

                parentControls
                architectureQuestionCard

                RefactoredStateInventoryView(
                    appUIState: appUIState,
                    catalogModel: catalogModel,
                    session: session,
                    services: services,
                    persistedLaunchCount: persistedLaunchCount
                )
                SearchAndNavigationPanel(appUIState: appUIState, catalogModel: catalogModel)
                CatalogFeaturePanel(model: catalogModel)
                ProfilePanel(session: session, appUIState: appUIState, catalogModel: catalogModel)
                DependencyPanel(services: services) {
                    services = .mock()
                    LabLog.event("ContentView replaced its dependency container")
                }
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

            Text("These resets are now explicit. UI/navigation-like state, feature state, session state, persistence, and dependencies no longer have to share one lifetime.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var architectureQuestionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prediction")
                .font(.headline)

            Text("Before using the controls, predict which object should change: AppUIState, CatalogFeatureModel, Session, AppServices, or persistedLaunchCount.")

            Text("The important improvement is semantic: reset/logout behavior now expresses intent instead of replacing one unrelated bag of mutable properties.")
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

private struct AppServices {
    let networkClient: NetworkClient
    let database: Database

    static func live() -> AppServices {
        AppServices(
            networkClient: NetworkClient(name: "Live API"),
            database: Database(name: "Catalog.sqlite")
        )
    }

    static func mock() -> AppServices {
        AppServices(
            networkClient: NetworkClient(name: "Mock API \(Int.random(in: 100...999))"),
            database: Database(name: "InMemory.sqlite")
        )
    }
}

private enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home = "Home"
    case catalog = "Catalog"
    case favorites = "Favorites"
    case profile = "Profile"

    var id: Self { self }
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

private struct UserProfile: Equatable {
    var displayName: String
    var isSignedIn: Bool

    static let sample = UserProfile(displayName: "Mauro", isSignedIn: true)
    static let signedOut = UserProfile(displayName: "Guest", isSignedIn: false)
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

private struct RefactoredStateInventoryView: View {
    let appUIState: AppUIState
    let catalogModel: CatalogFeatureModel
    let session: Session
    let services: AppServices
    let persistedLaunchCount: Int

    init(
        appUIState: AppUIState,
        catalogModel: CatalogFeatureModel,
        session: Session,
        services: AppServices,
        persistedLaunchCount: Int
    ) {
        self.appUIState = appUIState
        self.catalogModel = catalogModel
        self.session = session
        self.services = services
        self.persistedLaunchCount = persistedLaunchCount
        LabLog.event("RefactoredStateInventoryView init")
    }

    var body: some View {
        let _ = LabLog.event("RefactoredStateInventoryView body")

        VStack(alignment: .leading, spacing: 12) {
            Text("Responsibilities are now separated")
                .font(.headline)

            StateCategoryRow(owner: "AppUIState", name: "selectedTab", currentValue: appUIState.selectedTab.rawValue, category: "Application UI state")
            StateCategoryRow(owner: "AppUIState", name: "catalogPath", currentValue: "\(appUIState.catalogPath.count) route value(s)", category: "Navigation-like state")
            StateCategoryRow(owner: "AppUIState", name: "isShowingSettingsSheet", currentValue: appUIState.isShowingSettingsSheet ? "true" : "false", category: "Presentation state")
            StateCategoryRow(owner: "CatalogFeatureModel", name: "searchText", currentValue: catalogModel.searchText.isEmpty ? "empty" : catalogModel.searchText, category: "Feature UI state")
            StateCategoryRow(owner: "CatalogFeatureModel", name: "items", currentValue: "\(catalogModel.items.count) item(s)", category: "Domain/cache state")
            StateCategoryRow(owner: "CatalogFeatureModel", name: "favoriteIDs", currentValue: "\(catalogModel.favoriteIDs.count) favorite(s)", category: "Feature/domain state")
            StateCategoryRow(owner: "Session", name: "profile", currentValue: session.profile?.displayName ?? "signed out", category: "Session/domain state")
            StateCategoryRow(owner: "AppServices", name: "networkClient", currentValue: services.networkClient.name, category: "Service/dependency")
            StateCategoryRow(owner: "AppServices", name: "database", currentValue: services.database.name, category: "Persistence dependency")
            StateCategoryRow(owner: "ContentView @State", name: "persistedLaunchCount", currentValue: "\(persistedLaunchCount)", category: "Persistent-state placeholder")

            Text("This inventory still reads many properties for teaching purposes, but the real state owners now have narrower responsibilities and different reset behavior.")
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
            Text("UI + navigation-like state")
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

            Text("Search text moved to the catalog feature; tab/path/sheet state stayed in AppUIState. They can now reset independently.")
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

            Text("CatalogFeatureModel owns catalog-specific mutable state. It does not know about tabs, sheets, sessions, databases, or network clients yet.")
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

            Text("This logout policy clears session-owned identity, app UI/navigation-like state, search text, and user-scoped favorites. It deliberately keeps item cache and services alive.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct DependencyPanel: View {
    let services: AppServices
    let onSwapDependencies: () -> Void

    init(services: AppServices, onSwapDependencies: @escaping () -> Void) {
        self.services = services
        self.onSwapDependencies = onSwapDependencies
        LabLog.event("DependencyPanel init")
    }

    var body: some View {
        let _ = LabLog.event("DependencyPanel body")

        VStack(alignment: .leading, spacing: 8) {
            Text("Services stored as model state")
                .font(.headline)

            Text("Network client: \(services.networkClient.name)")
            Text("Database: \(services.database.name)")

            Button("Swap dependency container") {
                onSwapDependencies()
            }

            Text("Services are dependencies owned at the composition boundary. They are not observable UI state, even if replacing the container is useful for previews/tests.")
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
