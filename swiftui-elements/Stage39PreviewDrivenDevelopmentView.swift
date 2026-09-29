import Observation
import SwiftUI

@MainActor
struct Stage39PreviewDrivenDevelopmentView: View {
    @Environment(\.itemRepository) private var itemRepository
    @State private var model: Stage39PreviewLabModel

    init() {
        _model = State(initialValue: Stage39PreviewLabModel())
    }

    init(model: Stage39PreviewLabModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Stage 39 - Preview-driven development") {
                    Text("Concept")
                        .font(.headline)
                    Text("Use #Preview as a fast, state-rich development harness. A preview should render deterministic states without waiting on live networking.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Problem")
                        .font(.headline)
                    Text("When a view only renders through runtime loading paths, edge states like empty, failure, and extreme text settings are easy to skip.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Prediction")
                        .font(.headline)
                    Text("Before running: if we swap preview repositories and environment values, which states change immediately, and which still require user interaction?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Implementation") {
                    Text("Current state: \(model.state.title)")
                        .font(.subheadline.weight(.semibold))

                    previewStatePanel

                    Button("Load from injected repository") {
                        let repository = itemRepository
                        Task {
                            await model.load(using: repository)
                        }
                    }

                    HStack {
                        Button("Loading") { model.state = .loading }
                        Button("Empty") { model.state = .empty }
                    }

                    HStack {
                        Button("Failure") { model.state = .failed("Offline preview failure") }
                        Button("Loaded") { model.state = .loaded(CatalogItem.samples) }
                    }

                    Text("This stage keeps preview state explicit so each #Preview can focus on one behavior without network timing noise.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Run") {
                    Text("1) Build and run, then tap each state button to see deterministic transitions.")
                    Text("2) Tap 'Load from injected repository' and compare output between app runtime and previews.")
                    Text("3) Open the preview canvas and cycle through loaded/loading/empty/failure plus environment-focused previews.")
                }

                Section("Explanation") {
                    Text("Preview blocks are just view constructors with injected dependencies and environment overrides. They let you validate identity, layout, and semantics for multiple states without driving the full app flow every time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Repository injection keeps previews deterministic and avoids accidental coupling to live services.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Refactor") {
                    Text("As feature complexity grows, keep preview builders close to the feature and expose small factories for representative states.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Takeaway") {
                    Text("- Previews are a development runtime, not static screenshots.")
                    Text("- Model explicit states so previews can target them directly.")
                    Text("- Inject preview dependencies; avoid live networking in canvas flows.")
                }
            }
            .navigationTitle("Preview Driven")
        }
        .onAppear {
            LabLog.event("Stage39PreviewDrivenDevelopmentView onAppear")
        }
    }

    @ViewBuilder
    private var previewStatePanel: some View {
        switch model.state {
        case .loading:
            HStack(spacing: 10) {
                ProgressView()
                Text("Loading catalog...")
                    .foregroundStyle(.secondary)
            }

        case .empty:
            Label("No items available", systemImage: "tray")
                .foregroundStyle(.secondary)

        case .failed(let message):
            VStack(alignment: .leading, spacing: 6) {
                Label("Failed to load", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .loaded(let items):
            VStack(alignment: .leading, spacing: 8) {
                Text("Loaded \(items.count) item(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                        Text(item.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if item.id != items.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

@MainActor
@Observable
final class Stage39PreviewLabModel {
    var state: Stage39ContentState = .loaded(CatalogItem.samples)

    func load(using repository: any ItemRepository) async {
        state = .loading

        do {
            let items = try await repository.featuredItems()
            state = items.isEmpty ? .empty : .loaded(items)
            LabLog.event("Stage39 loaded \(items.count) item(s) from \(repository.diagnosticName)")
        } catch {
            state = .failed(error.localizedDescription)
            LabLog.event("Stage39 failed via \(repository.diagnosticName): \(error.localizedDescription)")
        }
    }

    static func preview(_ state: Stage39ContentState) -> Stage39PreviewLabModel {
        let model = Stage39PreviewLabModel()
        model.state = state
        return model
    }
}

enum Stage39ContentState {
    case loading
    case loaded([CatalogItem])
    case empty
    case failed(String)

    var title: String {
        switch self {
        case .loading:
            return "loading"
        case .loaded:
            return "loaded"
        case .empty:
            return "empty"
        case .failed:
            return "failed"
        }
    }
}

private enum Stage39PreviewError: LocalizedError {
    case offline

    var errorDescription: String? {
        switch self {
        case .offline:
            return "The preview repository is offline."
        }
    }
}

private let stage39LongLocalizedItems: [CatalogItem] = [
    CatalogItem(
        id: "localized-1",
        title: "A very long localized catalog title used to stress wrapping behavior",
        subtitle: "This subtitle simulates translated copy that can expand significantly and should still remain readable."
    ),
    CatalogItem(
        id: "localized-2",
        title: "Second long entry for preview validation",
        subtitle: "Use this to quickly verify spacing, truncation choices, and vertical rhythm under large text."
    )
]

#Preview("Stage 39 - Loaded") {
    Stage39PreviewDrivenDevelopmentView(model: .preview(.loaded(CatalogItem.samples)))
        .environment(\.itemRepository, PreviewItemRepository(name: "Preview loaded", items: CatalogItem.samples))
}

#Preview("Stage 39 - Loading") {
    Stage39PreviewDrivenDevelopmentView(model: .preview(.loading))
        .environment(\.itemRepository, PreviewItemRepository(name: "Preview loading"))
}

#Preview("Stage 39 - Empty") {
    Stage39PreviewDrivenDevelopmentView(model: .preview(.empty))
        .environment(\.itemRepository, PreviewItemRepository(name: "Preview empty", items: []))
}

#Preview("Stage 39 - Failure") {
    Stage39PreviewDrivenDevelopmentView(model: .preview(.failed("The preview repository is offline.")))
        .environment(
            \.itemRepository,
            TestItemRepository(name: "Preview failure", result: .failure(Stage39PreviewError.offline))
        )
}

#Preview("Stage 39 - Dark mode") {
    Stage39PreviewDrivenDevelopmentView(model: .preview(.loaded(CatalogItem.samples)))
        .preferredColorScheme(.dark)
        .environment(\.itemRepository, PreviewItemRepository(name: "Preview dark mode"))
}

#Preview("Stage 39 - Large Dynamic Type") {
    Stage39PreviewDrivenDevelopmentView(model: .preview(.loaded(CatalogItem.samples)))
        .environment(\.dynamicTypeSize, .accessibility3)
        .environment(\.itemRepository, PreviewItemRepository(name: "Preview accessibility size"))
}

#Preview("Stage 39 - Long localized content") {
    Stage39PreviewDrivenDevelopmentView(model: .preview(.loaded(stage39LongLocalizedItems)))
        .environment(\.locale, Locale(identifier: "de"))
        .environment(\.itemRepository, PreviewItemRepository(name: "Preview localized", items: stage39LongLocalizedItems))
}
