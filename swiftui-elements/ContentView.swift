import SwiftUI

@MainActor
struct ContentView: View {
    @State private var parentRevision = 0
    @State private var usesAlternateBranch = false
    @State private var explicitIdentity = UUID()
    @State private var usesUnstableIdentity = false

    init() {
        LabLog.event("ContentView init")
    }

    var body: some View {
        let _ = LabLog.event("ContentView body")

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Stage 2: Identity & Lifetime")
                    .font(.title.bold())

                Text("Identity is SwiftUI's answer to: is this the same logical UI node as before? State, tasks, and view-owned models live as long as that identity lives.")
                    .foregroundStyle(.secondary)

                Divider()

                parentControls

                identityConceptCard

                structuralIdentityExperiment
                explicitIdentityExperiment
                unstableIdentityExperiment
            }
            .padding()
        }
        .onAppear {
            LabLog.event("ContentView onAppear")
        }
        .onDisappear {
            LabLog.event("ContentView onDisappear")
        }
    }

    private var parentControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Parent revision: \(parentRevision)")

            Button("Recompute parent") {
                parentRevision += 1
                LabLog.event("parentRevision changed to \(parentRevision)")
            }
        }
        .stageCard()
    }

    private var identityConceptCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Working definition")
                .font(.headline)

            Text("A view's identity is not the View struct instance. It is SwiftUI's internal match between yesterday's node and today's node in the rendered tree.")
        }
        .stageCard()
    }

    private var structuralIdentityExperiment: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Experiment A: structural identity")
                .font(.headline)

            Text("Both branches create the same visual counter type, but they are different structural positions in the body tree.")
                .foregroundStyle(.secondary)

            Toggle("Use alternate branch", isOn: $usesAlternateBranch)

            if usesAlternateBranch {
                IdentityCounterView(name: "Branch TRUE counter")
            } else {
                IdentityCounterView(name: "Branch FALSE counter")
            }
        }
        .stageCard()
    }

    private var explicitIdentityExperiment: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Experiment B: explicit .id")
                .font(.headline)

            Text("Changing .id tells SwiftUI: treat this as a different logical node, even though it is in the same structural position.")
                .foregroundStyle(.secondary)

            Button("Change explicit identity") {
                explicitIdentity = UUID()
                LabLog.event("explicitIdentity changed to \(explicitIdentity)")
            }

            IdentityCounterView(name: "Explicit .id counter")
                .id(explicitIdentity)
        }
        .stageCard()
    }

    private var unstableIdentityExperiment: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Experiment C: unstable identity anti-pattern")
                .font(.headline)

            Text("When enabled, the counter gets .id(UUID()) during rendering. Every parent recomputation gives it a new identity and destroys its local state.")
                .foregroundStyle(.secondary)

            Toggle("Use unstable .id(UUID())", isOn: $usesUnstableIdentity)

            if usesUnstableIdentity {
                IdentityCounterView(name: "Unstable UUID counter")
                    .id(UUID())
            } else {
                IdentityCounterView(name: "Stable structural counter")
            }
        }
        .stageCard()
    }
}

private struct IdentityCounterView: View {
    let name: String

    @State private var count = 0
    @State private var model: LifetimeProbe

    init(name: String) {
        self.name = name
        _model = State(initialValue: LifetimeProbe(name: "\(name) model"))
        LabLog.event("\(name) init")
    }

    var body: some View {
        let _ = LabLog.event("\(name) body")

        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.subheadline.bold())

            Text("Local @State count: \(count)")

            Text("Model identity: \(model.idString)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            Button("Increment local state") {
                count += 1
                LabLog.event("\(name) count changed to \(count)")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            LabLog.event("\(name) onAppear")
        }
        .onDisappear {
            LabLog.event("\(name) onDisappear")
        }
        .task {
            let taskID = UUID()
            LabLog.event("\(name) task started: \(taskID)")

            do {
                try await Task.sleep(for: .seconds(60))
                LabLog.event("\(name) task completed: \(taskID)")
            } catch {
                LabLog.event("\(name) task cancelled: \(taskID)")
            }
        }
    }
}

private struct StageCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

private extension View {
    func stageCard() -> some View {
        modifier(StageCardModifier())
    }
}

private final class LifetimeProbe {
    private let name: String
    private let id = UUID()

    var idString: String {
        id.uuidString
    }

    init(name: String) {
        self.name = name
        LabLog.event("\(name) init: \(id)")
    }

    deinit {
        LabLog.event("\(name) deinit: \(id)")
    }
}

private enum LabLog {
    nonisolated static func event(_ message: String) {
        print("🧪 \(message)")
    }
}

#Preview {
    ContentView()
}
