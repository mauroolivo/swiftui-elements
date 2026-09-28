import Observation
import SwiftUI

@MainActor
struct Stage38UITestingView: View {
    @State private var model = Stage38Model()

    var body: some View {
        NavigationStack(path: $model.catalogPath) {
            List {
                Section("Stage 38 - UI testing") {
                    Text("Concept")
                        .font(.headline)
                    Text("Keep UI tests focused on critical user journeys. Validate a few high-value flows end-to-end, and keep business rules in model tests.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Problem")
                        .font(.headline)
                    Text("Without stable accessibility identifiers, UI tests become brittle and tied to incidental layout details.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Prediction")
                        .font(.headline)
                    Text("Before running tests: after logout, which states should reset immediately, and which should persist?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Implementation") {
                    HStack(spacing: 8) {
                        ForEach(Stage38Tab.allCases) { tab in

                            Button {
                                model.selectTab(tab)
                            } label: {
                                Text(tab.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(model.selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("stage38.tab.\(tab.identifierSuffix)")
                            .accessibilityValue(model.selectedTab == tab ? "selected" : "not selected")
                        }
                    }

                    Text(model.isSignedIn ? "Session: signed in" : "Session: signed out")
                        .font(.subheadline)
                        .accessibilityIdentifier("stage38.sessionStateLabel")

                    Text("Catalog path count: \(model.catalogPath.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("stage38.pathCountLabel")

                    Text("Favorites count: \(model.favorites.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("stage38.favoritesCountLabel")
                }

                Section(model.selectedTab.rawValue) {
                    switch model.selectedTab {
                    case .home:
                        Text("Home tab keeps this stage intentionally small.")
                            .foregroundStyle(.secondary)
                    case .catalog:
                        catalogPanel
                    case .search:
                        searchPanel
                    case .profile:
                        profilePanel
                    }
                }

                Section("Run") {
                    Text("1) Open Catalog and tap an item row to push detail.")
                    Text("2) Toggle favorite on detail, then return.")
                    Text("3) Open Search and filter with query text.")
                    Text("4) Open Profile and log out; verify tab and navigation reset.")
                }

                Section("Takeaway") {
                    Text("- Use identifiers for durable UI tests, not pixel-level assertions.")
                    Text("- Cover only critical paths in UI tests; keep most rules in model tests.")
                }
            }
            .navigationTitle("UI Testing")
            .navigationDestination(for: Stage38Route.self) { route in
                switch route {
                case .item(let id):
                    Stage38ItemDetailView(itemID: id, model: model)
                }
            }
        }
        .onAppear {
            LabLog.event("Stage38UITestingView onAppear")
        }
    }

    private var catalogPanel: some View {
        ForEach(model.items) { item in
            HStack(spacing: 12) {
                Button {
                    model.catalogPath.append(.item(item.id))
                    LabLog.event("Stage38 pushed item route \(item.id)")
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.subheadline.bold())
                        Text(item.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("stage38.catalog.open.\(item.id)")

                Button {
                    model.toggleFavorite(itemID: item.id)
                } label: {
                    Image(systemName: model.favorites.contains(item.id) ? "star.fill" : "star")
                        .foregroundStyle(.yellow)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("stage38.catalog.favorite.\(item.id)")
            }
        }
    }

    private var searchPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search catalog", text: $model.searchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("stage38.searchField")

            Text("Results: \(model.filteredItems.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("stage38.searchResultsCount")

            ForEach(model.filteredItems) { item in
                Text(item.title)
                    .accessibilityIdentifier("stage38.search.result.\(item.id)")
            }
        }
    }

    private var profilePanel: some View {
        HStack(spacing: 12) {
            if model.isSignedIn {
                Button("Logout") {
                    model.logout()
                }
                .accessibilityIdentifier("stage38.logoutButton")
            } else {
                Button("Sign in sample") {
                    model.signInSample()
                }
                .accessibilityIdentifier("stage38.signInButton")
            }
        }
    }
}

@MainActor
@Observable
private final class Stage38Model {
    var selectedTab: Stage38Tab = .home
    var catalogPath: [Stage38Route] = []
    var searchQuery = ""
    var isSignedIn = true
    var favorites: Set<Stage38Item.ID> = []

    let items: [Stage38Item] = [
        Stage38Item(id: "identity", title: "Identity", subtitle: "Stable IDs keep navigation predictable."),
        Stage38Item(id: "state", title: "State", subtitle: "Ownership defines reset policy."),
        Stage38Item(id: "observation", title: "Observation", subtitle: "Only read properties create dependencies.")
    ]

    var filteredItems: [Stage38Item] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter { item in
            item.title.localizedCaseInsensitiveContains(query) ||
            item.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    func toggleFavorite(itemID: Stage38Item.ID) {
        if favorites.contains(itemID) {
            favorites.remove(itemID)
        } else {
            favorites.insert(itemID)
        }
        LabLog.event("Stage38 toggled favorite \(itemID)")
    }

    func logout() {
        isSignedIn = false
        selectedTab = .home
        catalogPath.removeAll()
        searchQuery = ""
        favorites.removeAll()
        LabLog.event("Stage38 logout reset applied")
    }

    func selectTab(_ tab: Stage38Tab) {
        selectedTab = tab

        if tab != .catalog {
            catalogPath.removeAll()
        }

        LabLog.event("Stage38 selected tab \(tab.rawValue)")
    }

    func signInSample() {
        isSignedIn = true
        LabLog.event("Stage38 signed in sample user")
    }
}

private enum Stage38Tab: String, CaseIterable, Identifiable {
    case home = "Home"
    case catalog = "Catalog"
    case search = "Search"
    case profile = "Profile"

    var id: Self { self }

    var identifierSuffix: String {
        rawValue.lowercased()
    }
}

private enum Stage38Route: Hashable {
    case item(String)
}

private struct Stage38Item: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
}

private struct Stage38ItemDetailView: View {
    let itemID: Stage38Item.ID
    let model: Stage38Model

    private var item: Stage38Item? {
        model.items.first(where: { $0.id == itemID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Back") {
                if !model.catalogPath.isEmpty {
                    model.catalogPath.removeLast()
                }
            }
            .accessibilityIdentifier("stage38.detail.backButton")

            Text(item?.title ?? "Missing item")
                .font(.title3.bold())
                .accessibilityIdentifier("stage38.detail.title")

            Text(item?.subtitle ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(model.favorites.contains(itemID) ? "Unfavorite" : "Favorite") {
                model.toggleFavorite(itemID: itemID)
            }
            .accessibilityIdentifier("stage38.detail.favorite.\(itemID)")

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .navigationTitle("Detail")
    }
}

#Preview("Stage 38") {
    Stage38UITestingView()
}
