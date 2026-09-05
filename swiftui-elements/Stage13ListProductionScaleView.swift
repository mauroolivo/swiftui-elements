import SwiftUI

@MainActor
@Observable
final class Stage13CatalogListModel {
    struct Row: Identifiable, Hashable {
        let id: String
        var title: String
        var subtitle: String
        var category: Category
        var isFavorite: Bool

        enum Category: String, CaseIterable, Identifiable, Hashable {
            case foundations = "Foundations"
            case architecture = "Architecture"
            case production = "Production"

            var id: Self { self }
        }
    }

    var rows: [Row] = []
    var isLoading = false
    var errorMessage: String?
    var lastRefresh: Date?
    private var nextIncrementalID = 1
    
    init() {
        LabLog.event("Stage13CatalogListModel init")
    }

    deinit {
        LabLog.event("Stage13CatalogListModel deinit")
    }

    func loadInitialIfNeeded() async {
        guard rows.isEmpty else { return }
        await reload(simulateFailure: false)
    }

    func reload(simulateFailure: Bool) async {
        isLoading = true
        errorMessage = nil

        do {
            try await Task.sleep(for: .milliseconds(500))
            if simulateFailure {
                throw URLError(.badServerResponse)
            }

            rows = Self.seedRows
            isLoading = false
            lastRefresh = Date()
            LabLog.event("Stage13 reload succeeded with \(rows.count) rows")
        } catch {
            isLoading = false
            errorMessage = "Failed to load. Pull to refresh or tap Retry."
            LabLog.event("Stage13 reload failed: \(error.localizedDescription)")
        }
    }

    func addIncrementalRow() {
        let idNumber = nextIncrementalID
        nextIncrementalID += 1
        let category = Row.Category.allCases[idNumber % Row.Category.allCases.count]
        rows.insert(
            Row(
                id: "incremental-\(idNumber)",
                title: "Incremental Row \(idNumber)",
                subtitle: "Inserted to test stable list identity",
                category: category,
                isFavorite: false
            ),
            at: min(1, rows.count)
        )
        logDuplicateIDsIfAny()
    }

    func removeLastRow() {
        guard !rows.isEmpty else { return }
        rows.removeLast()
    }

    func renameFirstRow() {
        guard !rows.isEmpty else { return }
        rows[0].title += " *"
    }

    func toggleFavorite(for id: Row.ID) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        rows[index].isFavorite.toggle()
    }

    func delete(at offsets: IndexSet, in sectionRows: [Row]) {
        let ids = Set(offsets.compactMap { sectionRows[$0].id })
        rows.removeAll { ids.contains($0.id) }
    }

    func delete(_ id: Row.ID) {
        rows.removeAll { $0.id == id }
        logDuplicateIDsIfAny()
    }

    private func logDuplicateIDsIfAny() {
        var seen = Set<Row.ID>()
        let duplicates = rows.compactMap { row -> Row.ID? in
            if seen.insert(row.id).inserted { return nil }
            return row.id
        }

        if duplicates.isEmpty {
            LabLog.event("Stage13 IDs unique (\(rows.count) rows)")
        } else {
            LabLog.event("Stage13 duplicate IDs detected: \(duplicates)")
        }
    }

    static let seedRows: [Row] = [
        Row(id: "identity", title: "Identity", subtitle: "Stable ids preserve row lifetime", category: .foundations, isFavorite: false),
        Row(id: "lifetime", title: "Lifetime", subtitle: "State survives by identity", category: .foundations, isFavorite: true),
        Row(id: "observation", title: "Observation", subtitle: "Only read properties invalidate", category: .architecture, isFavorite: false),
        Row(id: "routing", title: "Routing", subtitle: "Navigation is explicit state", category: .architecture, isFavorite: false),
        Row(id: "restoration", title: "Restoration", subtitle: "Persist only what should survive", category: .production, isFavorite: true),
        Row(id: "accessibility", title: "Accessibility", subtitle: "Semantic labels and actions", category: .production, isFavorite: false)
    ]
}

@MainActor
struct Stage13ListProductionScaleView: View {
    @State private var model = Stage13CatalogListModel()
    @State private var query = ""
    @State private var scrollTarget: Stage13CatalogListModel.Row.ID?

    init() {
        LabLog.event("Stage13ListProductionScaleView init")
    }

    var body: some View {
        let _ = LabLog.event("Stage13ListProductionScaleView body")

        NavigationStack {
            Group {
                if model.isLoading && model.rows.isEmpty {
                    ProgressView("Loading catalog...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = model.errorMessage, model.rows.isEmpty {
                    ContentUnavailableView("Load Failed", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                } else if filteredRows.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List {
                        ForEach(Stage13CatalogListModel.Row.Category.allCases) { category in
                            let sectionRows = filteredRows.filter { $0.category == category }
                            if !sectionRows.isEmpty {
                                Section("\(category.rawValue) \(sectionRows.count)") {
                                    ForEach(sectionRows) { row in
                                        Stage13RowView(
                                            row: row,
                                            onToggleFavorite: { model.toggleFavorite(for: row.id) },
                                            onDelete: { model.delete(row.id) }
                                        )
                                    }
                                    .onDelete { offsets in
                                        model.delete(at: offsets, in: sectionRows)
                                    }
                                }
                            }
                        }
                    }
                    .scrollPosition(id: $scrollTarget)
                }
            }
            .navigationTitle("Stage 13 List")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Top") {
                        scrollTarget = filteredRows.first?.id
                    }

                    Menu("Mutate") {
                        Button("Insert row") { model.addIncrementalRow() }
                        Button("Rename first") { model.renameFirstRow() }
                        Button("Remove last") { model.removeLastRow() }
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button("Retry") {
                        Task { await model.reload(simulateFailure: false) }
                    }
                }
            }
            .refreshable {
                await model.reload(simulateFailure: false)
            }
            .searchable(text: $query, prompt: "Filter by title or subtitle")
            .safeAreaInset(edge: .bottom) {
                Stage13Footer(lastRefresh: model.lastRefresh, rowCount: filteredRows.count)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
            }
        }
        .task {
            await model.loadInitialIfNeeded()
        }
    }

    private var filteredRows: [Stage13CatalogListModel.Row] {
        if query.isEmpty { return model.rows }
        return model.rows.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }
}

private struct Stage13RowView: View {
    let row: Stage13CatalogListModel.Row
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.title)
                    .font(.headline)

                Spacer()

                Image(systemName: row.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(.yellow)
                    .accessibilityLabel(row.isFavorite ? "Favorite" : "Not favorite")
            }

            Text(row.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                onToggleFavorite()
            } label: {
                Label(row.isFavorite ? "Unfavorite" : "Favorite", systemImage: row.isFavorite ? "star.slash" : "star")
            }
            .tint(.yellow)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

private struct Stage13Footer: View {
    let lastRefresh: Date?
    let rowCount: Int

    var body: some View {
        HStack {
            Text("Rows: \(rowCount)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(lastRefreshText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var lastRefreshText: String {
        guard let lastRefresh else { return "Never refreshed" }
        return "Refreshed \(lastRefresh.formatted(date: .omitted, time: .standard))"
    }
}

#Preview("Stage 13 lists at production scale") {
    Stage13ListProductionScaleView()
}
