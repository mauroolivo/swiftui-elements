import SwiftUI

@MainActor
struct Stage14LoadingStateModelingView: View {
    @State private var model = Stage14LoadingStateModel()
    @State private var query = ""
    @State private var source: Stage14LoadingStateModel.Scenario = .success

    init() {
        LabLog.event("Stage14LoadingStateModelingView init")
    }

    var body: some View {
        let _ = LabLog.event("Stage14LoadingStateModelingView body")

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    controls
                    stateSummary
                    Divider()
                    content
                }
                .padding()
            }
            .navigationTitle("Stage 14 Loading State")
            .refreshable {
                await model.load(query: query, scenario: source)
            }
        }
        .task(id: taskID) {
            await model.load(query: query, scenario: source)
        }
    }

    private var taskID: String {
        "\(source.rawValue)|\(query.lowercased())"
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle:
            ContentUnavailableView(
                "Idle",
                systemImage: "pause.circle",
                description: Text("Adjust controls to trigger a load.")
            )

        case .loading:
            VStack(spacing: 12) {
                ProgressView("Loading lessons...")
                Text("Task id: \(taskID)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let lessons):
            if lessons.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {                
                ForEach(lessons) { lesson in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lesson.title)
                            .font(.headline)
                        Text(lesson.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

        case .failed(let message):
            ContentUnavailableView(
                "Load Failed",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
            .overlay(alignment: .bottom) {
                Button("Retry") {
                    Task {
                        await model.load(query: query, scenario: source)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 12)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Explicit load state beats boolean soup")
                .font(.headline)

            Picker("Scenario", selection: $source) {
                ForEach(Stage14LoadingStateModel.Scenario.allCases) { scenario in
                    Text(scenario.label).tag(scenario)
                }
            }
            .pickerStyle(.segmented)

            TextField("Search by title", text: $query)
                .textFieldStyle(.roundedBorder)

            Text("Type quickly or change scenario: .task(id:) cancels the previous in-flight request when identity changes.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var stateSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Current state: \(model.state.label)", systemImage: model.state.iconName)
            Text("Last event: \(model.lastEvent)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

@MainActor
@Observable
final class Stage14LoadingStateModel {
    enum Scenario: String, CaseIterable, Identifiable {
        case success
        case empty
        case failure

        var id: Self { self }

        var label: String {
            switch self {
            case .success: return "Success"
            case .empty: return "Empty"
            case .failure: return "Failure"
            }
        }
    }

    var state: LoadState<[Lesson]> = .idle
    var lastEvent = "Not loaded yet"

    init() {
        LabLog.event("Stage14LoadingStateModel init")
    }

    deinit {
        LabLog.event("Stage14LoadingStateModel deinit")
    }

    func load(query: String, scenario: Scenario) async {
        state = .loading
        lastEvent = "Loading \(scenario.label.lowercased()) for query '\(query)'"
        LabLog.event("Stage14 load started for scenario=\(scenario.rawValue), query=\(query)")

        do {
            try await Task.sleep(for: .milliseconds(3700))
            try Task.checkCancellation()

            switch scenario {
            case .success:
                let filtered = Self.seedLessons.filter {
                    query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)
                }
                state = .loaded(filtered)
                lastEvent = "Loaded \(filtered.count) lesson(s)"

            case .empty:
                state = .loaded([])
                lastEvent = "Loaded empty result"

            case .failure:
                throw URLError(.badServerResponse)
            }

            LabLog.event("Stage14 load completed with state=\(state.label)")
        } catch is CancellationError {
            lastEvent = "Canceled previous request"
            LabLog.event("Stage14 load canceled")
        } catch {
            state = .failed("The request failed. Pull to refresh or tap Retry.")
            lastEvent = "Failed: \(error.localizedDescription)"
            LabLog.event("Stage14 load failed: \(error.localizedDescription)")
        }
    }

    struct Lesson: Identifiable, Hashable {
        let id: String
        let title: String
        let summary: String
    }

    private static let seedLessons: [Lesson] = [
        Lesson(id: "identity", title: "Identity", summary: "State survives when identity stays stable."),
        Lesson(id: "ownership", title: "Ownership", summary: "Pick one source of truth per mutable value."),
        Lesson(id: "navigation", title: "Navigation", summary: "Navigation is explicit app state, not imperative pushes."),
        Lesson(id: "observation", title: "Observation", summary: "SwiftUI tracks the properties each view reads.")
    ]
}

enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)

    var label: String {
        switch self {
        case .idle: return "idle"
        case .loading: return "loading"
        case .loaded: return "loaded"
        case .failed: return "failed"
        }
    }

    var iconName: String {
        switch self {
        case .idle: return "pause.circle"
        case .loading: return "clock"
        case .loaded: return "checkmark.circle"
        case .failed: return "xmark.circle"
        }
    }
}

#Preview("Stage 14 loading-state modeling") {
    Stage14LoadingStateModelingView()
}
