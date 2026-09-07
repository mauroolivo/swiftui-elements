import Observation
import SwiftUI

private struct Stage15SeedLibrary {
    static let items: [Stage15ConcurrencyModel.WorkItem] = [
        Stage15ConcurrencyModel.WorkItem(id: "structured", title: "Structured task", detail: "Follows view identity and cancels automatically."),
        Stage15ConcurrencyModel.WorkItem(id: "manual", title: "Manual Task", detail: "Must be stored and canceled explicitly."),
        Stage15ConcurrencyModel.WorkItem(id: "detached", title: "Detached task", detail: "Does not inherit actor context and requires an explicit MainActor hop."),
        Stage15ConcurrencyModel.WorkItem(id: "lifetime", title: "Lifetime alignment", detail: "Prefer task lifetime that matches the owner of the work.")
    ]
}

@MainActor
struct Stage15SwiftConcurrencyLifecycleView: View {
    @State private var model = Stage15ConcurrencyModel()
    @State private var query = "swift"
    @State private var showStructuredWorker = true

    init() {
        LabLog.event("Stage15SwiftConcurrencyLifecycleView init")
    }

    var body: some View {
        let _ = LabLog.event("Stage15SwiftConcurrencyLifecycleView body")

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    controls
                    stateSummary

                    Divider()

                    if showStructuredWorker {
                        StructuredTaskPanel(query: query, model: model)
                    } else {
                        ContentUnavailableView(
                            "Structured task hidden",
                            systemImage: "eye.slash",
                            description: Text("Turn it back on to restart the `.task(id:)` work and observe cancellation when identity changes.")
                        )
                    }

                    Divider()

                    lifecycleNotes
                }
                .padding()
            }
            .navigationTitle("Stage 15 Concurrency")
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Task lifetime follows the abstraction that created it")
                .font(.headline)

            TextField("Task query", text: $query)
                .textFieldStyle(.roundedBorder)

            Toggle("Show structured `.task(id:)` panel", isOn: $showStructuredWorker)

            HStack {
                Button("Launch manual Task") {
                    model.startManualTask(query: query)
                }

                Button("Launch detached Task") {
                    model.startDetachedTask(query: query)
                }
            }

            HStack {
                Button("Cancel manual Task") {
                    model.cancelManualTask()
                }

                Button("Cancel detached Task") {
                    model.cancelDetachedTask()
                }
            }

            Text("The structured panel cancels automatically when its identity disappears. The manual `Task {}` must be stored and canceled explicitly. `Task.detached` does not inherit the current actor, so it needs an explicit hop back to `MainActor` before it touches UI state.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var stateSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Structured state: \(model.structuredState.label)", systemImage: model.structuredState.iconName)
            Text("Structured event: \(model.structuredEvent)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Manual Task status: \(model.manualTaskStatus)")
                .font(.caption)

            Text("Detached Task status: \(model.detachedTaskStatus)")
                .font(.caption)

            Text("Last event: \(model.lastEvent)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var lifecycleNotes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What to watch")
                .font(.headline)

            Text("1. Type quickly in the query field: the structured `.task(id:)` should cancel and restart.")
            Text("2. Hide the structured panel: the task cancels because the view identity disappears.")
            Text("3. Launch a manual task and a detached task, then change the query or hide the panel: they continue until you cancel them or they finish.")

            Text("This is the task-lifetime rule in practice: structured concurrency should line up with the view or feature that owns the work. Unstructured work needs an explicit owner and cancellation policy.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct StructuredTaskPanel: View {
    let query: String
    let model: Stage15ConcurrencyModel

    init(query: String, model: Stage15ConcurrencyModel) {
        self.query = query
        self.model = model
        LabLog.event("StructuredTaskPanel init")
    }

    var body: some View {
        let _ = LabLog.event("StructuredTaskPanel body")

        VStack(alignment: .leading, spacing: 12) {
            Text("Structured `.task(id:)`")
                .font(.headline)

            switch model.structuredState {
            case .idle:
                ContentUnavailableView(
                    "Idle",
                    systemImage: "pause.circle",
                    description: Text("Type to start the structured load.")
                )

            case .loading:
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView("Loading structured work…")
                    Text("Task identity: \(query.lowercased())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            case .loaded(let items):
                if items.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                            Text(item.detail)
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
            }
        }
        .stageCard()
        .task(id: query.lowercased()) {
            await model.loadStructured(query: query)
        }
        .onDisappear {
            LabLog.event("StructuredTaskPanel onDisappear")
        }
    }
}

@MainActor
@Observable
final class Stage15ConcurrencyModel {
    struct WorkItem: Identifiable, Hashable {
        let id: String
        let title: String
        let detail: String
    }

    var structuredState: LoadState<[WorkItem]> = .idle
    var structuredEvent = "Awaiting input"
    var manualTaskStatus = "Not started"
    var detachedTaskStatus = "Not started"
    var lastEvent = "Idle"

    @ObservationIgnored
    private var manualTask: Task<Void, Never>?

    @ObservationIgnored
    private var detachedTask: Task<Void, Never>?

    @ObservationIgnored
    private var manualRunCount = 0

    @ObservationIgnored
    private var detachedRunCount = 0

    init() {
        LabLog.event("Stage15ConcurrencyModel init")
    }

    deinit {
        manualTask?.cancel()
        detachedTask?.cancel()
        LabLog.event("Stage15ConcurrencyModel deinit")
    }

    func loadStructured(query: String) async {
        structuredState = .loading
        structuredEvent = "Structured load started for '\(query)'"
        lastEvent = structuredEvent
        LabLog.event("Stage15 structured task started for query=\(query)")

        do {
            try await Task.sleep(for: .milliseconds(1800))
            try Task.checkCancellation()

            let filtered = Stage15SeedLibrary.items.filter {
                query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.detail.localizedCaseInsensitiveContains(query)
            }

            structuredState = .loaded(filtered)
            structuredEvent = "Structured load finished with \(filtered.count) item(s)"
            lastEvent = structuredEvent
            LabLog.event("Stage15 structured task completed with \(filtered.count) item(s)")
        } catch is CancellationError {
            structuredEvent = "Structured load canceled"
            lastEvent = structuredEvent
            LabLog.event("Stage15 structured task canceled")
        } catch {
            structuredState = .failed("The structured task failed unexpectedly.")
            structuredEvent = "Structured load failed: \(error.localizedDescription)"
            lastEvent = structuredEvent
            LabLog.event("Stage15 structured task failed: \(error.localizedDescription)")
        }
    }

    func startManualTask(query: String) {
        manualTask?.cancel()
        manualRunCount += 1

        let run = manualRunCount
        let snapshot = query
        manualTaskStatus = "Manual Task #\(run) started for '\(snapshot)'"
        lastEvent = manualTaskStatus
        LabLog.event("Stage15 manual Task started run=\(run) query=\(snapshot)")

        manualTask = Task { [snapshot, run] in
            do {
                try await Task.sleep(for: .milliseconds(3000))
                try Task.checkCancellation()

                let filtered = Stage15SeedLibrary.items.filter {
                    snapshot.isEmpty || $0.title.localizedCaseInsensitiveContains(snapshot) || $0.detail.localizedCaseInsensitiveContains(snapshot)
                }

                manualTaskStatus = "Manual Task #\(run) finished with \(filtered.count) item(s)"
                lastEvent = manualTaskStatus
                LabLog.event("Stage15 manual Task completed run=\(run) with \(filtered.count) item(s)")
            } catch is CancellationError {
                manualTaskStatus = "Manual Task #\(run) canceled"
                lastEvent = manualTaskStatus
                LabLog.event("Stage15 manual Task canceled run=\(run)")
            } catch {
                manualTaskStatus = "Manual Task #\(run) failed: \(error.localizedDescription)"
                lastEvent = manualTaskStatus
                LabLog.event("Stage15 manual Task failed run=\(run): \(error.localizedDescription)")
            }
        }
    }

    func cancelManualTask() {
        manualTask?.cancel()
        manualTask = nil
        manualTaskStatus = "Manual Task canceled by user"
        lastEvent = manualTaskStatus
        LabLog.event("Stage15 manual Task canceled by user")
    }

    func startDetachedTask(query: String) {
        detachedTask?.cancel()
        detachedRunCount += 1

        let run = detachedRunCount
        let snapshot = query
        detachedTaskStatus = "Detached Task #\(run) started for '\(snapshot)'"
        lastEvent = detachedTaskStatus
        LabLog.event("Stage15 detached Task started run=\(run) query=\(snapshot)")

        detachedTask = Task.detached(priority: .background) { [snapshot, run] in
            do {
                try await Task.sleep(for: .milliseconds(3600))
                try Task.checkCancellation()

                let items = await MainActor.run { Stage15SeedLibrary.items }
                let filtered = items.filter {
                    snapshot.isEmpty || $0.title.localizedCaseInsensitiveContains(snapshot) || $0.detail.localizedCaseInsensitiveContains(snapshot)
                }

                await MainActor.run {
                    self.detachedTaskStatus = "Detached Task #\(run) finished with \(filtered.count) item(s)"
                    self.lastEvent = self.detachedTaskStatus
                    LabLog.event("Stage15 detached Task completed run=\(run) with \(filtered.count) item(s)")
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.detachedTaskStatus = "Detached Task #\(run) canceled"
                    self.lastEvent = self.detachedTaskStatus
                    LabLog.event("Stage15 detached Task canceled run=\(run)")
                }
            } catch {
                await MainActor.run {
                    self.detachedTaskStatus = "Detached Task #\(run) failed: \(error.localizedDescription)"
                    self.lastEvent = self.detachedTaskStatus
                    LabLog.event("Stage15 detached Task failed run=\(run): \(error.localizedDescription)")
                }
            }
        }
    }

    func cancelDetachedTask() {
        detachedTask?.cancel()
        detachedTask = nil
        detachedTaskStatus = "Detached Task canceled by user"
        lastEvent = detachedTaskStatus
        LabLog.event("Stage15 detached Task canceled by user")
    }
}

#Preview("Stage 15 concurrency lifecycle") {
    Stage15SwiftConcurrencyLifecycleView()
}
