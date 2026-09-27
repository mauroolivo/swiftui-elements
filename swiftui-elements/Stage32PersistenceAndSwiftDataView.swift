import SwiftData
import SwiftUI

@MainActor
struct Stage32PersistenceAndSwiftDataView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Stage32FavoriteRecord.createdAt, order: .forward)
    private var persistedFavorites: [Stage32FavoriteRecord]

    @State private var catalog = Stage32CatalogItem.samples
    @State private var searchText = ""

    private var persistedIDs: Set<String> {
        Set(persistedFavorites.map(\.itemID))
    }

    private var visibleCatalog: [Stage32CatalogItem] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return catalog }
        return catalog.filter {
            $0.title.localizedCaseInsensitiveContains(trimmedQuery)
                || $0.subtitle.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Stage 32 - Persistence and SwiftData") {
                    Text("Concept")
                        .font(.headline)
                    Text("`@Model` types represent persisted storage records. Domain types still model your feature language, and `@State` remains transient UI state.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Problem")
                        .font(.headline)
                    Text("If persistence objects become your entire app model, UI concerns and storage concerns get tightly coupled.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Prediction")
                        .font(.headline)
                    Text("Favorite two items, terminate and relaunch, then tap 'Reset transient UI state'. Which values should persist, and which should reset?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Implementation") {
                    TextField("Search in-memory catalog", text: $searchText)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("Reset transient UI state") {
                            searchText = ""
                            catalog = Stage32CatalogItem.samples
                        }

                        Spacer()

                        Button("Shuffle domain order") {
                            catalog.shuffle()
                        }
                    }

                    Button("Delete all persisted favorites", role: .destructive) {
                        for record in persistedFavorites {
                            modelContext.delete(record)
                        }
                        try? modelContext.save()
                    }
 
                    Text("`searchText` and catalog ordering are view/domain concerns. Favorite records are persisted in SwiftData.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
 
                Section("Catalog (domain model)") {
                    if visibleCatalog.isEmpty {
                        Text("No domain items match the current query")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(visibleCatalog) { item in
                            Button {
                                toggleFavorite(itemID: item.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                            .font(.subheadline.bold())
                                        Text(item.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: persistedIDs.contains(item.id) ? "star.fill" : "star")
                                        .foregroundStyle(.yellow)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Persisted favorites (`@Query`)") {
                    if persistedFavorites.isEmpty {
                        Text("No persisted favorites yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(persistedFavorites) { favorite in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(favorite.itemID)
                                    .font(.subheadline.monospaced())
                                Text(favorite.createdAt, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Run") {
                    Text("1) Favorite a few items and relaunch the app.")
                    Text("2) Reset transient UI state and verify favorites remain.")
                    Text("3) Delete persisted favorites and confirm `@Query` updates immediately.")
                }

                Section("Explanation") {
                    Text("`Stage32FavoriteRecord` is a persistence boundary. `Stage32CatalogItem` stays a lightweight domain value. `searchText` is local view state. SwiftData should store what must survive termination, not every mutable value in the feature.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Takeaway") {
                    Text("- Use `@Model` for storage concerns, not as universal UI state.")
                    Text("- Keep domain models independent from persistence schemas when possible.")
                    Text("- Persist only state with real cross-launch value.")
                }
            }
            .navigationTitle("Persistence")
        }
        .onAppear {
            LabLog.event("Stage32PersistenceAndSwiftDataView onAppear")
        }
    }

    private func toggleFavorite(itemID: String) {
        if let existing = persistedFavorites.first(where: { $0.itemID == itemID }) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(Stage32FavoriteRecord(itemID: itemID))
        }

        try? modelContext.save()
    }
}

@Model
final class Stage32FavoriteRecord {
    @Attribute(.unique) var itemID: String
    var createdAt: Date

    init(itemID: String, createdAt: Date = .now) {
        self.itemID = itemID
        self.createdAt = createdAt
    }
}

private struct Stage32CatalogItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String

    static let samples: [Stage32CatalogItem] = [
        Stage32CatalogItem(id: "identity", title: "Identity", subtitle: "Persisted rows need stable IDs."),
        Stage32CatalogItem(id: "ownership", title: "Ownership", subtitle: "Storage and UI ownership are different concerns."),
        Stage32CatalogItem(id: "projection", title: "Projection", subtitle: "Map persistence models into domain and view state.")
    ]
}

#Preview("Stage 32") {
    Stage32PersistenceAndSwiftDataView()
        .modelContainer(for: [Stage32FavoriteRecord.self], inMemory: true)
}
