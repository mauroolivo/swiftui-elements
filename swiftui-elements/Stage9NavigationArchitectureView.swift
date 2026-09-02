import SwiftUI

@Observable
final class AppRouter {
    var selectedTab: AppTab = .home
    var homePath: [HomeRoute] = []
    var catalogPath: [CatalogRoute] = []
    var searchPath: [SearchRoute] = []
    var favoritesPath: [FavoritesRoute] = []

    init() {
        LabLog.event("AppRouter init")
    }

    deinit {
        LabLog.event("AppRouter deinit")
    }

    func openCatalogItem(_ itemID: CatalogItem.ID, source: String) {
        selectedTab = .catalog
        catalogPath.append(.item(itemID))
        LabLog.event("AppRouter opened catalog item \(itemID) from \(source)")
    }

    func showSearchResult(_ itemID: CatalogItem.ID, source: String) {
        selectedTab = .search
        searchPath.append(.result(itemID))
        LabLog.event("AppRouter opened search result \(itemID) from \(source)")
    }

    func showFavorite(_ itemID: CatalogItem.ID, source: String) {
        selectedTab = .favorites
        favoritesPath.append(.item(itemID))
        LabLog.event("AppRouter opened favorite item \(itemID) from \(source)")
    }

    func resetCurrentTabPath() {
        switch selectedTab {
        case .home:
            homePath.removeAll()
        case .catalog:
            catalogPath.removeAll()
        case .search:
            searchPath.removeAll()
        case .favorites:
            favoritesPath.removeAll()
        case .profile:
            break
        }

        LabLog.event("AppRouter reset path for \(selectedTab.rawValue)")
    }

    func resetAllPaths() {
        homePath.removeAll()
        catalogPath.removeAll()
        searchPath.removeAll()
        favoritesPath.removeAll()
        LabLog.event("AppRouter reset all tab paths")
    }

    func resetForLogout() {
        selectedTab = .home
        resetAllPaths()
        LabLog.event("AppRouter reset for logout")
    }
}

enum HomeRoute: Hashable {
    case note(String)
}

enum SearchRoute: Hashable {
    case result(CatalogItem.ID)
}

enum FavoritesRoute: Hashable {
    case item(CatalogItem.ID)
}

@Observable
private final class Stage9CatalogModel {
    var query = ""
    var favoriteIDs: Set<CatalogItem.ID> = ["identity", "observation"]

    init() {
        LabLog.event("Stage9CatalogModel init")
    }

    deinit {
        LabLog.event("Stage9CatalogModel deinit")
    }

    var filteredItems: [CatalogItem] {
        guard !query.isEmpty else { return CatalogItem.samples }

        return CatalogItem.samples.filter { item in
            item.title.localizedCaseInsensitiveContains(query)
            || item.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    var favoriteItems: [CatalogItem] {
        CatalogItem.samples.filter { favoriteIDs.contains($0.id) }
    }

    func toggleFavorite(_ item: CatalogItem) {
        if favoriteIDs.contains(item.id) {
            favoriteIDs.remove(item.id)
        } else {
            favoriteIDs.insert(item.id)
        }

        LabLog.event("Stage9CatalogModel toggled favorite for \(item.id)")
    }
}

struct Stage9NavigationArchitectureView: View {
    @Environment(AppRouter.self) private var router
    @State private var model = Stage9CatalogModel()

    init() {
        LabLog.event("Stage9NavigationArchitectureView init")
    }

    var body: some View {
        let _ = LabLog.event("Stage9NavigationArchitectureView body")
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router.homePath) {
                HomeNavigationRoot(model: model)
                    .navigationDestination(for: HomeRoute.self) { route in
                        HomeRouteDestination(route: route)
                    }
            }
            .tabItem { Label(AppTab.home.rawValue, systemImage: "house") }
            .tag(AppTab.home)

            NavigationStack(path: $router.catalogPath) {
                CatalogNavigationRoot(model: model)
                    .navigationDestination(for: CatalogRoute.self) { route in
                        switch route {
                        case .item(let itemID):
                            ItemDetailScreen(itemID: itemID, source: "Catalog route")
                        }
                    }
            }
            .tabItem { Label(AppTab.catalog.rawValue, systemImage: "square.grid.2x2") }
            .tag(AppTab.catalog)

            NavigationStack(path: $router.searchPath) {
                SearchNavigationRoot(model: model)
                    .navigationDestination(for: SearchRoute.self) { route in
                        switch route {
                        case .result(let itemID):
                            ItemDetailScreen(itemID: itemID, source: "Search route")
                        }
                    }
            }
            .tabItem { Label(AppTab.search.rawValue, systemImage: "magnifyingglass") }
            .tag(AppTab.search)

            NavigationStack(path: $router.favoritesPath) {
                FavoritesNavigationRoot(model: model)
                    .navigationDestination(for: FavoritesRoute.self) { route in
                        switch route {
                        case .item(let itemID):
                            ItemDetailScreen(itemID: itemID, source: "Favorites route")
                        }
                    }
            }
            .tabItem { Label(AppTab.favorites.rawValue, systemImage: "star") }
            .tag(AppTab.favorites)

            NavigationStack {
                ProfileNavigationRoot(model: model)
            }
            .tabItem { Label(AppTab.profile.rawValue, systemImage: "person.crop.circle") }
            .tag(AppTab.profile)
        }
        .onAppear {
            LabLog.event("Stage9NavigationArchitectureView onAppear")
        }
        .onDisappear {
            LabLog.event("Stage9NavigationArchitectureView onDisappear")
        }
    }
}

private struct HomeNavigationRoot: View {
    let model: Stage9CatalogModel

    @Environment(AppRouter.self) private var router

    var body: some View {
        let _ = LabLog.event("HomeNavigationRoot body")

        List {
            Section("Concept") {
                Text("Stage 9: Navigation architecture")
                    .font(.title2.bold())

                Text("Stage 8 treated one NavigationStack path as local state. Stage 9 promotes navigation state only where there is a real cross-feature need: this shell router owns tab selection and one independent path per tab.")
                    .foregroundStyle(.secondary)
            }

            Section("Prediction") {
                Text("Navigate inside Catalog, switch to Search, navigate there, then return to Catalog. Predict whether Catalog's path is still alive.")
            }

            RouterInventoryRows()

            Section("Cross-feature routing") {
                Button("Open Identity in Catalog tab") {
                    router.openCatalogItem("identity", source: "Home")
                }

                Button("Open Observation in Search tab") {
                    router.showSearchResult("observation", source: "Home")
                }

                if let favorite = model.favoriteItems.first {
                    Button("Open first favorite in Favorites tab") {
                        router.showFavorite(favorite.id, source: "Home")
                    }
                }
            }

            Section("Local versus shared owner") {
                NavigationLink("Open tradeoff note", value: HomeRoute.note("tradeoffs"))

                Text("A feature can still own its own path with @State. This router exists because tab selection and cross-tab jumps are shell-level concerns. It is not a dumping ground for search text, favorites, services, or every screen's local presentation flags.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Reset policy") {
                Button("Reset current tab path") {
                    router.resetCurrentTabPath()
                }

                Button("Reset all tab paths") {
                    router.resetAllPaths()
                }
            }
        }
        .navigationTitle("Home")
    }
}

private struct CatalogNavigationRoot: View {
    let model: Stage9CatalogModel

    @Environment(AppRouter.self) private var router

    var body: some View {
        let _ = LabLog.event("CatalogNavigationRoot body")

        List {
            RouterInventoryRows()

            Section("Catalog") {
                ForEach(CatalogItem.samples) { item in
                    NavigationLink(value: CatalogRoute.item(item.id)) {
                        ItemRow(item: item, isFavorite: model.favoriteIDs.contains(item.id))
                    }
                    .swipeActions {
                        Button(model.favoriteIDs.contains(item.id) ? "Unfavorite" : "Favorite") {
                            model.toggleFavorite(item)
                        }
                        .tint(.yellow)
                    }
                }
            }

            Section("Programmatic routing") {
                Button("Append first item to this tab's path") {
                    if let item = CatalogItem.samples.first {
                        router.openCatalogItem(item.id, source: "Catalog button")
                    }
                }

                Text("Catalog owns catalog-specific destinations. The app shell router owns the Catalog path because Home and deep links may need to drive it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Catalog")
        .toolbar {
            Button("Clear") {
                router.catalogPath.removeAll()
                LabLog.event("AppRouter cleared catalogPath from toolbar")
            }
        }
    }
}

private struct SearchNavigationRoot: View {
    let model: Stage9CatalogModel

    @Environment(AppRouter.self) private var router

    var body: some View {
        let _ = LabLog.event("SearchNavigationRoot body")
        @Bindable var model = model

        List {
            RouterInventoryRows()

            Section("Search state is not router state") {
                TextField("Search catalog", text: $model.query)
                    .textFieldStyle(.roundedBorder)

                Text("The query is feature state. The selected tab and navigation path are navigation state. Keeping those separate prevents a router from becoming a giant view model.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Results") {
                if model.filteredItems.isEmpty {
                    ContentUnavailableView("No matches", systemImage: "magnifyingglass")
                } else {
                    ForEach(model.filteredItems) { item in
                        NavigationLink(value: SearchRoute.result(item.id)) {
                            ItemRow(item: item, isFavorite: model.favoriteIDs.contains(item.id))
                        }
                    }
                }
            }

            Section("Cross-feature action") {
                Button("Open first result in Catalog instead") {
                    if let item = model.filteredItems.first {
                        router.openCatalogItem(item.id, source: "Search")
                    }
                }
            }
        }
        .navigationTitle("Search")
        .toolbar {
            Button("Clear") {
                router.searchPath.removeAll()
                LabLog.event("AppRouter cleared searchPath from toolbar")
            }
        }
    }
}

private struct FavoritesNavigationRoot: View {
    let model: Stage9CatalogModel

    @Environment(AppRouter.self) private var router

    var body: some View {
        let _ = LabLog.event("FavoritesNavigationRoot body")

        List {
            RouterInventoryRows()

            Section("Favorites") {
                if model.favoriteItems.isEmpty {
                    ContentUnavailableView("No favorites", systemImage: "star")
                } else {
                    ForEach(model.favoriteItems) { item in
                        NavigationLink(value: FavoritesRoute.item(item.id)) {
                            ItemRow(item: item, isFavorite: true)
                        }
                    }
                }
            }

            Section("Ownership") {
                Text("Favorite IDs are feature/user data. The Favorites path only says which favorite screen is open. Those are related, but they are not the same state.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Favorites")
        .toolbar {
            Button("Clear") {
                router.favoritesPath.removeAll()
                LabLog.event("AppRouter cleared favoritesPath from toolbar")
            }
        }
    }
}

private struct ProfileNavigationRoot: View {
    let model: Stage9CatalogModel

    @Environment(AppRouter.self) private var router
    @Environment(Session.self) private var session

    var body: some View {
        let _ = LabLog.event("ProfileNavigationRoot body")

        List {
            Section("Session") {
                Label(session.profile?.displayName ?? "Guest", systemImage: session.profile == nil ? "person.crop.circle" : "person.crop.circle.fill")

                Text(session.profile == nil ? "Signed out" : "Signed in")
                    .foregroundStyle(.secondary)
            }

            Section("Logout reset policy") {
                Button("Logout and reset navigation") {
                    session.signOut()
                    model.query = ""
                    router.resetForLogout()
                }

                Button("Sign sample user back in") {
                    session.signInSampleUser()
                }

                Text("Logout is a shell-level event. Here it clears protected navigation paths and returns to Home, but it still does not require one global AppViewModel containing every feature detail.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Profile")
    }
}

private struct RouterInventoryRows: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        Section("Router state") {
            LabeledContent("Selected tab", value: router.selectedTab.rawValue)
            LabeledContent("Home path", value: "\(router.homePath.count)")
            LabeledContent("Catalog path", value: "\(router.catalogPath.count)")
            LabeledContent("Search path", value: "\(router.searchPath.count)")
            LabeledContent("Favorites path", value: "\(router.favoritesPath.count)")
        }
    }
}

private struct HomeRouteDestination: View {
    let route: HomeRoute

    var body: some View {
        switch route {
        case .note:
            List {
                Section("Router tradeoffs") {
                    Text("Local feature-owned path")
                        .font(.headline)
                    Text("Best when navigation is entirely internal to one feature and no parent needs to drive it.")
                        .foregroundStyle(.secondary)

                    Text("Shell-owned router")
                        .font(.headline)
                    Text("Useful when tabs, deep links, notifications, or cross-feature actions need to select a tab and mutate a path.")
                        .foregroundStyle(.secondary)

                    Text("Global router")
                        .font(.headline)
                    Text("Powerful, but easy to overuse. If every screen pushes through one global object, feature boundaries and ownership become blurry.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Tradeoffs")
        }
    }
}

private struct ItemDetailScreen: View {
    let itemID: CatalogItem.ID
    let source: String

    private var item: CatalogItem? {
        CatalogItem.samples.first { $0.id == itemID }
    }

    var body: some View {
        let _ = LabLog.event("ItemDetailScreen body for \(itemID)")

        List {
            Section("Route payload") {
                LabeledContent("Item ID", value: itemID)
                LabeledContent("Source", value: source)
            }

            Section("Resolved model") {
                if let item {
                    Text(item.title)
                        .font(.title2.bold())
                    Text(item.subtitle)
                        .foregroundStyle(.secondary)
                } else {
                    ContentUnavailableView("Missing item", systemImage: "exclamationmark.triangle")
                }
            }

            Section("Why IDs, not mutable models?") {
                Text("The route carries a lightweight stable identifier. The destination resolves current data from the feature/domain source, which keeps navigation state codable, comparable, and resilient to model edits.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(item?.title ?? "Item")
    }
}

private struct ItemRow: View {
    let item: CatalogItem
    let isFavorite: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.bold())
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Favorite")
            }
        }
    }
}

#Preview("Stage 9 navigation architecture") {
    Stage9NavigationArchitectureView()
        .environment(AppRouter())
        .environment(Session())
}
