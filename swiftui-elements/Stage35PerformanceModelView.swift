import Foundation
import SwiftUI

@MainActor
struct Stage35PerformanceModelView: View {
    @State private var model = Stage35PerformanceLabModel()
    @State private var identityRefreshToken = 0

    init() {
        LabLog.event("Stage35PerformanceModelView init")
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Stage 35 - Performance model") {
                    Text("Concept")
                        .font(.headline)
                    Text("SwiftUI performance work starts with the real cost model. Frequent `body` evaluation is normal. The question is not \"did this view recompute?\" but \"what expensive work happened because it recomputed, and was that work actually necessary?\"")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Problem")
                        .font(.headline)
                    Text("This lab intentionally mixes three different issues: a view that reads more observable state than it needs, a filter/sort pipeline that runs during rendering, and a list that uses unstable identity. Those bugs all look like \"SwiftUI is rebuilding everything\", but the real causes are different.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Prediction")
                        .font(.headline)
                    Text("Before running: if you only bump an unrelated pulse counter, which panel should recompute its expensive transform? And if a parent view refreshes while row IDs are regenerated from fresh UUIDs, what happens to each row's local state?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Implementation - dependency scope") {
                    Stage35DependencyControls(model: model)
                    Stage35NoisyResultsPanel(model: model)
                    Stage35FocusedResultsPanel(model: model)
                }

                Section("Implementation - identity and lifetime") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Trigger unrelated parent updates")
                            .font(.headline)

                        Text("Increment a row counter in both lists, then trigger the parent refresh button. Stable row identity keeps the local `@State` alive. Unstable row identity destroys it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Button("Refresh parent view") {
                                identityRefreshToken += 1
                                LabLog.event("Stage35 identity refresh token -> \(identityRefreshToken)")
                            }

                            Spacer()

                            Text("Token: \(identityRefreshToken)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        Stage35IdentityComparison(refreshToken: identityRefreshToken)
                    }
                    .stageCard()
                }

                Section("Other hotspots to investigate") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This stage only makes some performance problems visible in a small lab. In production, also inspect:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("• image decoding and resizing done on the main actor")
                        Text("• repeated sorting/filtering/formatting directly inside `body`")
                        Text("• environment reads that are not actually needed by a subtree")
                        Text("• giant observable models that force broad dependency surfaces")
                        Text("• unstable identity in lists, grids, and matched-geometry transitions")
                    }
                    .stageCard()
                }

                Section("Run") {
                    Text("1) Open the debug console and watch the `🧪` logs.")
                    Text("2) Press \"Bump unrelated pulse\" a few times. The noisy panel should log a new expensive transform; the focused panel should stay quiet.")
                    Text("3) Toggle the palette flag. Again, the noisy panel recomputes because it captured an unnecessary dependency.")
                    Text("4) Change the search query or sort order. Now both panels should recompute, because both legitimately depend on the visible results.")
                    Text("5) Increment row counters in both identity lists, then press \"Refresh parent view\". The stable list should keep its counters; the unstable list should reset them.")
                    Text("6) Optional: run Time Profiler and compare a series of pulse taps against a series of query edits. The question is where CPU time is spent, not whether `body` ran.")
                }

                Section("Explanation") {
                    Text("Observation tracks the specific properties each view reads. In this lab, the noisy panel reads `pulseCount` and `usesWarmPalette` even though they are irrelevant to the rendered results, so those unrelated mutations invalidate the view and rerun the expensive filter/sort work. The focused panel reads only `query`, `sortOrder`, and `items`, so unrelated mutations do not invalidate it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("The identity demo is a different problem. SwiftUI preserves local state for views it considers the same element over time. When IDs come from fresh UUIDs during rendering, SwiftUI treats every row as brand new, so row-local `@State` disappears and animations become unreliable.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Refactor") {
                    Text("The first refactor is usually not `equatable()`. Instead: narrow observable reads, move genuinely expensive derived work to a better boundary, cache or precompute when the inputs are stable, and keep IDs anchored in domain identity rather than render-time randomness.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Takeaway") {
                    Text("- `body` evaluation is a normal part of SwiftUI's rendering model; measure actual expensive work before optimizing.")
                    Text("- Observation dependencies come from properties a view reads, so broad reads create broad invalidation.")
                    Text("- Stable identity is a correctness requirement first and a performance requirement second.")
                }
            }
            .navigationTitle("Performance")
        }
        .onAppear {
            LabLog.event("Stage35PerformanceModelView onAppear")
        }
    }
}

@MainActor
@Observable
private final class Stage35PerformanceLabModel {
    var query = ""
    var sortOrder: Stage35SortOrder = .relevance
    var pulseCount = 0
    var usesWarmPalette = false
    let items: [Stage35CatalogEntry]

    init(items: [Stage35CatalogEntry] = Stage35CatalogEntry.samples) {
        self.items = items
        LabLog.event("Stage35PerformanceLabModel init with \(items.count) items")
    }

    deinit {
        LabLog.event("Stage35PerformanceLabModel deinit")
    }

    func bumpPulse() {
        pulseCount += 1
        LabLog.event("Stage35 pulseCount -> \(pulseCount)")
    }

    func togglePalette() {
        usesWarmPalette.toggle()
        LabLog.event("Stage35 usesWarmPalette -> \(usesWarmPalette)")
    }
}

private enum Stage35SortOrder: String, CaseIterable, Identifiable {
    case relevance = "Relevance"
    case title = "Title"
    case category = "Category"

    var id: Self { self }
}

private struct Stage35CatalogEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let category: String
    let subtitle: String
    let keywords: [String]

    var searchableText: String {
        ([title, category, subtitle] + keywords).joined(separator: " ")
    }

    nonisolated static let samples: [Stage35CatalogEntry] = {
        let topics = [
            "Identity", "Lifetime", "Observation", "Navigation", "Environment", "Animation",
            "Accessibility", "Concurrency", "Layout", "Persistence", "Search", "UIKit"
        ]
        let categories = ["Rendering", "Architecture", "State", "Performance", "Testing", "Lists"]
        let suffixes = ["lab", "notes", "demo", "benchmark", "exercise", "case study"]

        return (0..<480).map { index in
            let topic = topics[index % topics.count]
            let category = categories[(index / topics.count) % categories.count]
            let suffix = suffixes[index % suffixes.count]
            return Stage35CatalogEntry(
                id: "stage35-\(index)",
                title: "\(topic) \(index + 1)",
                category: category,
                subtitle: "\(suffix.capitalized) for \(topic.lowercased()) in \(category.lowercased())",
                keywords: [
                    topic.lowercased(),
                    category.lowercased(),
                    suffix,
                    index.isMultiple(of: 2) ? "swiftui" : "uikit",
                    index.isMultiple(of: 3) ? "body" : "identity",
                    index.isMultiple(of: 5) ? "observation" : "layout"
                ]
            )
        }
    }()
}

private struct Stage35MeasuredResults {
    let visibleItems: [Stage35CatalogEntry]
    let totalMatches: Int
    let elapsedMilliseconds: Double
}

private enum Stage35CatalogWorkload {
    static func measure(items: [Stage35CatalogEntry], query: String, sortOrder: Stage35SortOrder) -> Stage35MeasuredResults {
        let start = Date().timeIntervalSinceReferenceDate
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filtered = items.filter { item in
            if normalizedQuery.isEmpty {
                _ = rankingScore(for: item, query: normalizedQuery)
                return true
            }

            let haystack = item.searchableText.lowercased()
            let containsQuery = haystack.contains(normalizedQuery)
            if containsQuery {
                _ = rankingScore(for: item, query: normalizedQuery)
            }
            return containsQuery
        }

        let sorted = filtered.sorted { lhs, rhs in
            switch sortOrder {
            case .relevance:
                let leftScore = rankingScore(for: lhs, query: normalizedQuery)
                let rightScore = rankingScore(for: rhs, query: normalizedQuery)
                if leftScore == rightScore {
                    return lhs.title < rhs.title
                }
                return leftScore > rightScore
            case .title:
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            case .category:
                if lhs.category == rhs.category {
                    return lhs.title < rhs.title
                }
                return lhs.category < rhs.category
            }
        }

        let elapsed = (Date().timeIntervalSinceReferenceDate - start) * 1_000

        return Stage35MeasuredResults(
            visibleItems: Array(sorted.prefix(6)),
            totalMatches: filtered.count,
            elapsedMilliseconds: elapsed
        )
    }

    private static func rankingScore(for item: Stage35CatalogEntry, query: String) -> Int {
        let normalizedQuery = query.isEmpty ? "swiftui" : query
        var score = 0

        for keyword in item.keywords {
            if keyword.contains(normalizedQuery) {
                score += 12
            }

            score += keyword.unicodeScalars.reduce(into: 0) { partialResult, scalar in
                partialResult += Int(scalar.value % 7)
            }
        }

        if item.title.lowercased().contains(normalizedQuery) {
            score += 20
        }

        if item.subtitle.lowercased().contains(normalizedQuery) {
            score += 8
        }

        return score + item.category.count
    }
}

private struct Stage35DependencyControls: View {
    let model: Stage35PerformanceLabModel

    init(model: Stage35PerformanceLabModel) {
        self.model = model
        LabLog.event("Stage35DependencyControls init")
    }

    var body: some View {
        let _ = LabLog.event("Stage35DependencyControls body")
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 12) {
            Text("Mutate relevant and irrelevant inputs")
                .font(.headline)

            TextField("Search sample catalog", text: $model.query)
                .textFieldStyle(.roundedBorder)

            Picker("Sort order", selection: $model.sortOrder) {
                ForEach(Stage35SortOrder.allCases) { sortOrder in
                    Text(sortOrder.rawValue).tag(sortOrder)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button("Bump unrelated pulse") {
                    model.bumpPulse()
                }

                Button(model.usesWarmPalette ? "Disable palette flag" : "Toggle palette flag") {
                    model.togglePalette()
                }
            }

            Text("Query and sort order should invalidate both result panels. Pulse and palette should only matter to the noisy panel because it reads them unnecessarily.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct Stage35NoisyResultsPanel: View {
    let model: Stage35PerformanceLabModel

    init(model: Stage35PerformanceLabModel) {
        self.model = model
        LabLog.event("Stage35NoisyResultsPanel init")
    }

    var body: some View {
        let capturedPulse = model.pulseCount
        let capturedPalette = model.usesWarmPalette
        let measurement = Stage35CatalogWorkload.measure(items: model.items, query: model.query, sortOrder: model.sortOrder)
        let _ = LabLog.event("Stage35NoisyResultsPanel body pulse=\(capturedPulse) palette=\(capturedPalette) took \(String(format: "%.2f", measurement.elapsedMilliseconds)) ms")

        VStack(alignment: .leading, spacing: 12) {
            Text("Broken: broad dependencies")
                .font(.headline)

            Text("This panel reads `pulseCount` and `usesWarmPalette` even though they do not affect the visible results. Those unnecessary reads widen invalidation and rerun the expensive transform.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Stage35MeasurementSummary(measurement: measurement, dependencyNote: "Dependencies captured: query, sortOrder, items, pulseCount, usesWarmPalette")
        }
        .stageCard()
    }
}

private struct Stage35FocusedResultsPanel: View {
    let model: Stage35PerformanceLabModel

    init(model: Stage35PerformanceLabModel) {
        self.model = model
        LabLog.event("Stage35FocusedResultsPanel init")
    }

    var body: some View {
        let measurement = Stage35CatalogWorkload.measure(items: model.items, query: model.query, sortOrder: model.sortOrder)
        let _ = LabLog.event("Stage35FocusedResultsPanel body took \(String(format: "%.2f", measurement.elapsedMilliseconds)) ms")

        VStack(alignment: .leading, spacing: 12) {
            Text("Refactored: focused dependencies")
                .font(.headline)

            Text("This panel still performs the same expensive transform during rendering, but it only reads the properties that actually define the visible result set. Unrelated mutations therefore do not invalidate it.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Stage35MeasurementSummary(measurement: measurement, dependencyNote: "Dependencies captured: query, sortOrder, items")
        }
        .stageCard()
    }
}

private struct Stage35MeasurementSummary: View {
    let measurement: Stage35MeasuredResults
    let dependencyNote: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Matches")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(measurement.totalMatches)")
                    .font(.subheadline.monospacedDigit())
            }

            HStack(alignment: .firstTextBaseline) {
                Text("Transform time")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.2f ms", measurement.elapsedMilliseconds))
                    .font(.subheadline.monospacedDigit())
            }

            Text(dependencyNote)
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(measurement.visibleItems) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline.bold())
                    Text("\(item.category) • \(item.subtitle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct Stage35IdentityComparison: View {
    let refreshToken: Int

    private let samples = Stage35IdentitySample.samples

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Stable identity")
                    .font(.headline)
                Text("Rows are keyed by a domain ID, so local state survives unrelated parent updates.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(samples) { sample in
                    Stage35IdentityRow(title: sample.title)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Unstable identity")
                    .font(.headline)
                Text("These rows are wrapped in fresh render-time UUIDs every time the parent refreshes. SwiftUI therefore treats them as brand-new rows and their local state resets.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(unstableRows(for: refreshToken)) { sample in
                    Stage35IdentityRow(title: sample.title)
                }
            }
        }
    }

    private func unstableRows(for _: Int) -> [Stage35RenderedIdentitySample] {
        samples.map { sample in
            Stage35RenderedIdentitySample(id: UUID(), title: sample.title)
        }
    }
}

private struct Stage35IdentitySample: Identifiable {
    let id: String
    let title: String

    static let samples = [
        Stage35IdentitySample(id: "identity", title: "Identity lesson"),
        Stage35IdentitySample(id: "state", title: "State ownership lab"),
        Stage35IdentitySample(id: "layout", title: "Layout benchmark")
    ]
}

private struct Stage35RenderedIdentitySample: Identifiable {
    let id: UUID
    let title: String
}

private struct Stage35IdentityRow: View {
    let title: String

    @State private var localCount = 0

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text("Local count: \(localCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Increment") {
                localCount += 1
                LabLog.event("Stage35IdentityRow \(title) localCount -> \(localCount)")
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}

#Preview("Stage 35 - Performance") {
    Stage35PerformanceModelView()
}
