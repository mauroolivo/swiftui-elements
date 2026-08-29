import SwiftUI
import UIKit

@MainActor
struct ContentView: View {
    @State private var parentRevision = 0
    @State private var showsCounter = true

    init() {
        LabLog.event("ContentView init")
    }

    var body: some View {
        let _ = LabLog.event("ContentView body")

        VStack(alignment: .leading, spacing: 16) {
            Text("Stage 1: Rendering Model")
                .font(.title.bold())

            Text("A SwiftUI View is a lightweight value description. Watch the console to compare View init/body with appear/disappear, @State lifetime, task lifetime, and an underlying UIKit view probe.")
                .foregroundStyle(.secondary)

            Divider()

            Text("Parent revision: \(parentRevision)")

            Button("Recompute parent") {
                parentRevision += 1
                LabLog.event("parentRevision changed to \(parentRevision)")
            }

            RenderedUIViewProbe(label: "UIKit probe updated by revision \(parentRevision)")

            Toggle("Show counter child", isOn: $showsCounter)

            if showsCounter {
                CounterExperimentView(title: "Stable structural child")
            }

            Spacer()
        }
        .padding()
        .onAppear {
            LabLog.event("ContentView onAppear")
        }
        .onDisappear {
            LabLog.event("ContentView onDisappear")
        }
    }
}

private struct CounterExperimentView: View {
    let title: String

    @State private var childCount = 0
    @State private var model = LifetimeProbe(name: "CounterExperimentView model")

    init(title: String) {
        self.title = title
        LabLog.event("CounterExperimentView init")
    }

    var body: some View {
        let _ = LabLog.event("CounterExperimentView body")

        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text("Child @State count: \(childCount)")

            Button("Increment child @State") {
                childCount += 1
                LabLog.event("childCount changed to \(childCount)")
            }

            Text("Model identity: \(model.idString)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            LabLog.event("CounterExperimentView onAppear")
        }
        .onDisappear {
            LabLog.event("CounterExperimentView onDisappear")
        }
        .task {
            let taskID = UUID()
            LabLog.event("CounterExperimentView task started: \(taskID)")

            do {
                try await Task.sleep(for: .seconds(60))
                LabLog.event("CounterExperimentView task completed: \(taskID)")
            } catch {
                LabLog.event("CounterExperimentView task cancelled: \(taskID)")
            }
        }
    }
}

private struct RenderedUIViewProbe: UIViewRepresentable {
    let label: String

    init(label: String) {
        self.label = label
        LabLog.event("RenderedUIViewProbe init")
    }

    func makeUIView(context: Context) -> UILabel {
        LabLog.event("RenderedUIViewProbe makeUIView")

        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        LabLog.event("RenderedUIViewProbe updateUIView")
        uiView.text = label
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
