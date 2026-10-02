import Observation
import SwiftUI

@MainActor
@Observable
final class Stage44TabsModel {
    var selectedTab: Stage44Tab = .home

    var homePath: [Stage44HomeRoute] = []
    var catalogPath: [Stage44CatalogRoute] = []
    var favoritesPath: [Stage44FavoritesRoute] = []

    var homeScrollID: CatalogItem.ID? = CatalogItem.samples.first?.id
    var catalogScrollID: CatalogItem.ID? = CatalogItem.samples.first?.id

    var homeDraftNote = "Observe which tab state survives switching."
    var catalogQuery = ""
    var favoriteIDs: Set<CatalogItem.ID> = ["identity"]

    init() {
        LabLog.event("Stage44TabsModel init")
    }

    deinit {
        LabLog.event("Stage44TabsModel deinit")
    }

    var filteredCatalogItems: [CatalogItem] {
        guard !catalogQuery.isEmpty else { return CatalogItem.samples }
        return CatalogItem.samples.filter {
            $0.title.localizedCaseInsensitiveContains(catalogQuery)
                || $0.subtitle.localizedCaseInsensitiveContains(catalogQuery)
        }
    }

    var favoriteItems: [CatalogItem] {
        CatalogItem.samples.filter { favoriteIDs.contains($0.id) }
    }

    func toggleFavorite(_ itemID: CatalogItem.ID) {
        if favoriteIDs.contains(itemID) {
            favoriteIDs.remove(itemID)
        } else {
            favoriteIDs.insert(itemID)
        }
        LabLog.event("Stage44 toggled favorite for \(itemID)")
    }

    func openItem(_ itemID: CatalogItem.ID, in tab: Stage44Tab, source: String, replacingPath: Bool) {
        selectedTab = tab

        switch tab {
        case .home:
            if replacingPath { homePath.removeAll() }
            homePath.append(.item(itemID))
        case .catalog:
            if replacingPath { catalogPath.removeAll() }
            catalogPath.append(.item(itemID))
        case .favorites:
            if replacingPath { favoritesPath.removeAll() }
            favoritesPath.append(.item(itemID))
        case .profile:
            break
        }

        LabLog.event("Stage44 open item \(itemID) in \(tab.rawValue) from \(source), replacingPath=\(replacingPath)")
    }

    func resetNavigationButKeepFeatureState() {
        homePath.removeAll()
        catalogPath.removeAll()
        favoritesPath.removeAll()
        selectedTab = .home
        LabLog.event("Stage44 reset navigation only")
    }
}

@MainActor
struct Stage44TabsIndependentFeatureStateView: View {
    @State private var shell = Stage44TabsModel()
    @State private var deepLinkText = "myapp://item/observation?tab=favorites&replace=1"
    @State private var deepLinkStatus = "Not executed"
    @State private var isControlPanelExpanded = false

    var body: some View {
        @Bindable var shell = shell

        TabView(selection: $shell.selectedTab) {
            NavigationStack(path: $shell.homePath) {
                Stage44HomeRoot(shell: shell)
                    .navigationDestination(for: Stage44HomeRoute.self) { route in
                        switch route {
                        case .item(let itemID):
                            Stage44ItemDetail(itemID: itemID, source: "Home path")
                        }
                    }
            }
            .tabItem { Label(Stage44Tab.home.rawValue, systemImage: "house") }
            .tag(Stage44Tab.home)

            NavigationStack(path: $shell.catalogPath) {
                Stage44CatalogRoot(shell: shell)
                    .navigationDestination(for: Stage44CatalogRoute.self) { route in
                        switch route {
                        case .item(let itemID):
                            Stage44ItemDetail(itemID: itemID, source: "Catalog path")
                        }
                    }
            }
            .tabItem { Label(Stage44Tab.catalog.rawValue, systemImage: "square.grid.2x2") }
            .tag(Stage44Tab.catalog)

            NavigationStack(path: $shell.favoritesPath) {
                Stage44FavoritesRoot(shell: shell)
                    .navigationDestination(for: Stage44FavoritesRoute.self) { route in
                        switch route {
                        case .item(let itemID):
                            Stage44ItemDetail(itemID: itemID, source: "Favorites path")
                        }
                    }
            }
            .tabItem { Label(Stage44Tab.favorites.rawValue, systemImage: "star") }
            .tag(Stage44Tab.favorites)

            NavigationStack {
                Stage44ProfileRoot(shell: shell)
            }
            .tabItem { Label(Stage44Tab.profile.rawValue, systemImage: "person.crop.circle") }
            .tag(Stage44Tab.profile)
        }
        .safeAreaInset(edge: .top) {
            Stage44ControlPanel(
                shell: shell,
                isExpanded: $isControlPanelExpanded,
                deepLinkText: $deepLinkText,
                deepLinkStatus: $deepLinkStatus
            )
        }
        .onAppear {
            LabLog.event("Stage44TabsIndependentFeatureStateView onAppear")
        }
    }
}

private struct Stage44ControlPanel: View {
    let shell: Stage44TabsModel
    @Binding var isExpanded: Bool
    @Binding var deepLinkText: String
    @Binding var deepLinkStatus: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stage 44 - Tabs and independent feature state")
                            .font(.headline)

                        Text("Selected tab: \(shell.selectedTab.rawValue) • Home \(shell.homePath.count) • Catalog \(shell.catalogPath.count) • Favorites \(shell.favoritesPath.count)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text("Concept: each tab owns independent navigation path + feature state, while tab selection stays app-shell state.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Problem: if all tabs share one path, switching tabs often destroys local context and scroll position.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Prediction: type in Catalog search, scroll Home, push a detail in Favorites, then switch tabs. Which values should still be there?")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Button("Notification -> Favorites item") {
                        shell.openItem("observation", in: .favorites, source: "Notification", replacingPath: false)
                    }

                    Button("Cross-feature -> Catalog item") {
                        shell.openItem("state", in: .catalog, source: "Cross-feature", replacingPath: false)
                    }

                    Button("Reset navigation") {
                        shell.resetNavigationButKeepFeatureState()
                    }
                }
                .buttonStyle(.bordered)

                TextField("Deep link", text: $deepLinkText)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Apply deep link") {
                        let result = Stage44DeepLinkParser.parse(text: deepLinkText)
                        switch result {
                        case let .success(link):
                            shell.openItem(
                                link.itemID,
                                in: link.targetTab,
                                source: "Deep link",
                                replacingPath: link.replacingPath
                            )
                            deepLinkStatus = "Opened \(link.itemID) in \(link.targetTab.rawValue), replace=\(link.replacingPath)"
                        case let .failure(error):
                            deepLinkStatus = error.errorDescription ?? "Invalid deep link"
                        }
                    }

                    Spacer(minLength: 0)
                }
                .buttonStyle(.borderedProminent)

                Text("Deep link status: \(deepLinkStatus)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)

                Text("Takeaway: keep tab-owned state local to each tab, and keep app-shell events (deep links, notifications, tab switches) at the shell boundary.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
}

private struct Stage44HomeRoot: View {
    let shell: Stage44TabsModel

    var body: some View {
        @Bindable var shell = shell

        List {
            Section("Home state") {
                TextField("Home-only draft", text: $shell.homeDraftNote)
                    .textFieldStyle(.roundedBorder)

                Text("This draft belongs only to Home. Tab switches should not erase it because owner lifetime is Stage44TabsModel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Home feed with scroll state") {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 8) {
                        ForEach(CatalogItem.samples) { item in
                            NavigationLink(value: Stage44HomeRoute.item(item.id)) {
                                Stage44ItemRow(item: item, isFavorite: shell.favoriteIDs.contains(item.id))
                            }
                            .id(item.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .frame(height: 220)
                .scrollPosition(id: $shell.homeScrollID, anchor: .top)
                .scrollTargetBehavior(.viewAligned)

                Text("Home scroll anchor: \(shell.homeScrollID ?? "nil")")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Home")
    }
}

private struct Stage44CatalogRoot: View {
    let shell: Stage44TabsModel

    var body: some View {
        @Bindable var shell = shell

        List {
            Section("Catalog query state") {
                TextField("Search catalog", text: $shell.catalogQuery)
                    .textFieldStyle(.roundedBorder)

                Text("Catalog query should survive switching to another tab and coming back.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Catalog list") {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 8) {
                        ForEach(shell.filteredCatalogItems) { item in
                            NavigationLink(value: Stage44CatalogRoute.item(item.id)) {
                                Stage44ItemRow(item: item, isFavorite: shell.favoriteIDs.contains(item.id))
                            }
                            .contextMenu {
                                Button(shell.favoriteIDs.contains(item.id) ? "Unfavorite" : "Favorite") {
                                    shell.toggleFavorite(item.id)
                                }
                            }
                            .id(item.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .frame(height: 260)
                .scrollPosition(id: $shell.catalogScrollID, anchor: .top)
                .scrollTargetBehavior(.viewAligned)

                Text("Catalog scroll anchor: \(shell.catalogScrollID ?? "nil")")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Catalog")
        .toolbar {
            Button("Clear path") {
                shell.catalogPath.removeAll()
            }
        }
    }
}

private struct Stage44FavoritesRoot: View {
    let shell: Stage44TabsModel

    var body: some View {
        List {
            Section("Favorites") {
                if shell.favoriteItems.isEmpty {
                    ContentUnavailableView("No favorites", systemImage: "star")
                } else {
                    ForEach(shell.favoriteItems) { item in
                        NavigationLink(value: Stage44FavoritesRoute.item(item.id)) {
                            Stage44ItemRow(item: item, isFavorite: true)
                        }
                    }
                }
            }

            Section("Cross-feature action") {
                Button("Open first favorite in Catalog tab") {
                    if let first = shell.favoriteItems.first {
                        shell.openItem(first.id, in: .catalog, source: "Favorites tab", replacingPath: false)
                    }
                }

                Text("This button simulates a tab-local action that needs to switch tabs programmatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Favorites")
        .toolbar {
            Button("Clear path") {
                shell.favoritesPath.removeAll()
            }
        }
    }
}

private struct Stage44ProfileRoot: View {
    let shell: Stage44TabsModel

    var body: some View {
        List {
            Section("Path inventory") {
                LabeledContent("Selected tab", value: shell.selectedTab.rawValue)
                LabeledContent("Home path", value: "\(shell.homePath.count)")
                LabeledContent("Catalog path", value: "\(shell.catalogPath.count)")
                LabeledContent("Favorites path", value: "\(shell.favoritesPath.count)")
            }

            Section("Run") {
                Text("1) Type in Home draft + Catalog query.")
                Text("2) Push details in multiple tabs.")
                Text("3) Trigger Notification/Cross-feature buttons in top panel.")
                Text("4) Return to each tab and verify state preservation.")
            }

            Section("Explanation") {
                Text("Tab selection is shell state. Per-tab path, query, and scroll anchors are feature state. Keeping those separated prevents one global route enum from becoming a bottleneck.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Profile")
    }
}

private struct Stage44ItemDetail: View {
    let itemID: CatalogItem.ID
    let source: String

    var body: some View {
        let item = CatalogItem.samples.first { $0.id == itemID }

        List {
            Section("Route payload") {
                LabeledContent("Item ID", value: itemID)
                LabeledContent("Source", value: source)
            }

            Section("Resolved item") {
                if let item {
                    Text(item.title)
                        .font(.title2.bold())
                    Text(item.subtitle)
                        .foregroundStyle(.secondary)
                } else {
                    ContentUnavailableView("Missing item", systemImage: "exclamationmark.triangle")
                }
            }

            Section("Why this payload") {
                Text("Routes carry stable IDs instead of whole mutable models. Each tab keeps independent path values.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(item?.title ?? "Item")
    }
}

private struct Stage44ItemRow: View {
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
            }
        }
    }
}

enum Stage44Tab: String, CaseIterable, Identifiable {
    case home = "Home"
    case catalog = "Catalog"
    case favorites = "Favorites"
    case profile = "Profile"

    var id: Self { self }
}

enum Stage44HomeRoute: Hashable {
    case item(CatalogItem.ID)
}

enum Stage44CatalogRoute: Hashable {
    case item(CatalogItem.ID)
}

enum Stage44FavoritesRoute: Hashable {
    case item(CatalogItem.ID)
}

struct Stage44DeepLink {
    let itemID: CatalogItem.ID
    let targetTab: Stage44Tab
    let replacingPath: Bool
}

enum Stage44DeepLinkParseError: LocalizedError {
    case invalidURL
    case invalidFormat
    case unsupportedTab(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidFormat:
            return "Expected format: myapp://item/<id>?tab=<home|catalog|favorites>&replace=0|1"
        case let .unsupportedTab(tab):
            return "Unsupported tab '\(tab)'. Use home, catalog, or favorites."
        }
    }
}

enum Stage44DeepLinkParser {
    static func parse(text: String) -> Result<Stage44DeepLink, Stage44DeepLinkParseError> {
        guard let url = URL(string: text), let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return .failure(.invalidURL)
        }

        let host = components.host ?? ""
        let pathID = components.path.split(separator: "/").first.map(String.init) ?? ""

        guard host == "item", !pathID.isEmpty else {
            return .failure(.invalidFormat)
        }

        let queryItems = components.queryItems ?? []
        let tabValue = queryItems.first(where: { $0.name == "tab" })?.value ?? "catalog"
        let replaceValue = queryItems.first(where: { $0.name == "replace" })?.value ?? "0"

        let tab: Stage44Tab
        switch tabValue.lowercased() {
        case "home":
            tab = .home
        case "catalog":
            tab = .catalog
        case "favorites":
            tab = .favorites
        default:
            return .failure(.unsupportedTab(tabValue))
        }

        return .success(
            Stage44DeepLink(
                itemID: pathID,
                targetTab: tab,
                replacingPath: replaceValue == "1"
            )
        )
    }
}

#Preview("Stage 44") {
    Stage44TabsIndependentFeatureStateView()
        .environment(AppRouter())
        .environment(AppUIState())
        .environment(Session())
        .environment(\.itemRepository, PreviewItemRepository(name: "Stage 44 preview"))
}
