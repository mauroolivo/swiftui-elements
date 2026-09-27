import Observation
import SwiftUI

@MainActor
struct Stage30SearchArchitectureView: View {
    @State private var model = Stage30SearchModel(repository: Stage30MockSearchRepository())

    var body: some View {
        NavigationStack {
            List {
                Section("Stage 30 - Search architecture") {
                    Text("Concept")
                        .font(.headline)
                    Text("Search is not one boolean. Keep query state, result state, and async side effects explicit so cancellation and retries are predictable.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Problem")
                        .font(.headline)
                    Text("Starting unmanaged tasks for every character creates race conditions and stale results. The latest query should win, and previous work should cancel.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Prediction")
                        .font(.headline)
                    Text("Type quickly: \"s\", \"sw\", \"swi\", \"swift\". Which searches complete, and which are canceled?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Implementation") {
                    Text("This stage drives search with `.searchable` + `.task(id:)` tied to query text. SwiftUI cancels the previous task when query changes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !model.recentQueries.isEmpty {
                        Text("Recent: \(model.recentQueries.joined(separator: ", "))")
                            .font(.caption)
                    }
                }

                Section("Results") {
                    Stage30ResultsView(loadState: model.loadState)
                }

                Section("Run") {
                    Text("1) Type `swift` slowly, then quickly backspace and type `layout`.")
                    Text("2) Tap a suggestion and confirm it becomes the active query.")
                    Text("3) Search `error` and use Retry.")
                }

                Section("Event log") {
                    if model.eventLog.isEmpty {
                        Text("No events yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(model.eventLog.enumerated()), id: \.offset) { _, event in
                            Text(event)
                                .font(.caption)
                        }
                    }
                }

                Section("Takeaway") {
                    Text("- Keep search query state separate from async result state.")
                    Text("- Use `.task(id:)` for cancellation aligned with view/query lifetime.")
                    Text("- Debounce before calling the repository, then model loading/loaded/failed explicitly.")
                }
            }
            .navigationTitle("Search")
            .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search topics")
            .searchSuggestions {
                ForEach(model.suggestions, id: \.self) { suggestion in
                    Text(suggestion)
                        .searchCompletion(suggestion)
                }
            }
            .task(id: model.query) {
                // The task runs when the view first appears.
                // It runs again every time model.query changes to a different value
                // Before the new run starts, SwiftUI cancels the previous task instance
                // That cancellation is why your catch is CancellationError path gets hit during fast typing
                await model.searchForCurrentQuery()
            }
        }
        .onAppear {
            LabLog.event("Stage30SearchArchitectureView onAppear")
        }
    }
}

private struct Stage30ResultsView: View {
    let loadState: Stage30SearchModel.LoadState

    var body: some View {
        switch loadState {
        case .idle:
            Text("Type to start searching.")
                .foregroundStyle(.secondary)
        case .loading(let query):
            HStack(spacing: 10) {
                ProgressView()
                Text("Searching for \"\(query)\"...")
            }
        case .loaded(let query, let results):
            if results.isEmpty {
                Text("No results for \"\(query)\".")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(results) { result in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.title)
                            .font(.subheadline.bold())
                        Text(result.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        case .failed(let query, let message):
            VStack(alignment: .leading, spacing: 8) {
                Text("Search failed for \"\(query)\".")
                    .font(.subheadline.bold())
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

@MainActor
@Observable
private final class Stage30SearchModel {
    enum LoadState {
        case idle
        case loading(query: String)
        case loaded(query: String, results: [Stage30SearchResult])
        case failed(query: String, message: String)
    }

    var query = ""
    var loadState: LoadState = .idle
    var recentQueries: [String] = []
    var eventLog: [String] = []

    private let repository: any Stage30SearchRepository

    init(repository: any Stage30SearchRepository) {
        self.repository = repository
        record("Search model initialized")
    }

    var suggestions: [String] {
        let staticSuggestions = ["swift", "navigation", "layout", "observation", "animation"]
        let base = Array((recentQueries + staticSuggestions).uniqued())
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return Array(base.prefix(5))
        }

        return base
            .filter { $0.localizedCaseInsensitiveContains(trimmed) }
            .prefix(5)
            .map { $0 }
    }

    func searchForCurrentQuery() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            loadState = .idle
            record("Query cleared -> idle")
            return
        }

        do {
            record("Debounce start for query: \(trimmed)")
            try await Task.sleep(for: .milliseconds(300))
            try Task.checkCancellation()

            loadState = .loading(query: trimmed)
            record("Searching query: \(trimmed)")

            let results = try await repository.search(query: trimmed)
            try Task.checkCancellation()

            // Cancellation is triggered by SwiftUI, not by your model, at:
            // - query change (.task(id: model.query) { ... })
            loadState = .loaded(query: trimmed, results: results)
            pushRecent(trimmed)
            record("Search completed for \(trimmed) with \(results.count) result(s)")
        } catch is CancellationError {
            record("Search canceled for query: \(trimmed)")
        } catch {
            loadState = .failed(query: trimmed, message: error.localizedDescription)
            record("Search failed for \(trimmed): \(error.localizedDescription)")
        }
    }

    private func pushRecent(_ value: String) {
        recentQueries.removeAll { $0.caseInsensitiveCompare(value) == .orderedSame }
        recentQueries.insert(value, at: 0)
        if recentQueries.count > 6 {
            recentQueries = Array(recentQueries.prefix(6))
        }
    }

    private func record(_ message: String) {
        eventLog.insert(message, at: 0)
        LabLog.event("Stage30SearchModel: \(message)")
    }
}

private struct Stage30SearchResult: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
}

private protocol Stage30SearchRepository {
    func search(query: String) async throws -> [Stage30SearchResult]
}

private struct Stage30MockSearchRepository: Stage30SearchRepository {
    private let entries: [Stage30SearchResult] = [
        Stage30SearchResult(id: "r1", title: "SwiftUI Rendering", subtitle: "View values are transient descriptions."),
        Stage30SearchResult(id: "r2", title: "NavigationStack Routes", subtitle: "Model navigation as state."),
        Stage30SearchResult(id: "r3", title: "Observation Dependencies", subtitle: "Views update for properties they read."),
        Stage30SearchResult(id: "r4", title: "Layout Protocol", subtitle: "Parent proposes, child chooses, parent places."),
        Stage30SearchResult(id: "r5", title: "Animation Transactions", subtitle: "Track which state mutation animates."),
        Stage30SearchResult(id: "r6", title: "Search Cancellation", subtitle: "Latest query should win."),
        Stage30SearchResult(id: "r7", title: "Debounced Search", subtitle: "Avoid fire-on-every-keystroke network load.")
    ]

    func search(query: String) async throws -> [Stage30SearchResult] {
        try await Task.sleep(for: .milliseconds(450))

        if query.caseInsensitiveCompare("error") == .orderedSame {
            throw Stage30SearchError.simulatedFailure
        }

        return entries.filter { result in
            result.title.localizedCaseInsensitiveContains(query) || result.subtitle.localizedCaseInsensitiveContains(query)
        }
    }
}

private enum Stage30SearchError: LocalizedError {
    case simulatedFailure

    var errorDescription: String? {
        switch self {
        case .simulatedFailure:
            return "Simulated backend failure. This is where typed error mapping would happen."
        }
    }
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}

#Preview("Stage 30") {
    Stage30SearchArchitectureView()
}
