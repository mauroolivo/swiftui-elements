import SwiftUI

struct ContentView: View {
    @State private var count = 0
    @State private var showsProbe = true

    init() {
        LabLog.event("ContentView init")
    }

    var body: some View {
        let _ = LabLog.event("ContentView body")

        VStack(alignment: .leading, spacing: 16) {
            Text("SwiftUI Laboratory")
                .font(.title.bold())

            Text("This screen is intentionally small. Its job is to make SwiftUI lifetime events visible in the console.")
                .foregroundStyle(.secondary)

            Divider()

            Text("Local @State count: \(count)")

            Button("Increment count") {
                count += 1
                LabLog.event("count changed to \(count)")
            }

            Toggle("Show diagnostic child", isOn: $showsProbe)

            if showsProbe {
                DiagnosticChildView()
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

private struct DiagnosticChildView: View {
    @State private var model = DiagnosticModel(name: "DiagnosticChildView model")

    init() {
        LabLog.event("DiagnosticChildView init")
    }

    var body: some View {
        let _ = LabLog.event("DiagnosticChildView body")

        VStack(alignment: .leading, spacing: 8) {
            Text("Diagnostic child")
                .font(.headline)

            Text(model.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            LabLog.event("DiagnosticChildView onAppear")
        }
        .onDisappear {
            LabLog.event("DiagnosticChildView onDisappear")
        }
        .task {
            let taskID = UUID()
            LabLog.event("DiagnosticChildView task started: \(taskID)")

            do {
                try await Task.sleep(for: .seconds(60))
                LabLog.event("DiagnosticChildView task completed: \(taskID)")
            } catch {
                LabLog.event("DiagnosticChildView task cancelled: \(taskID)")
            }
        }
    }
}

private final class DiagnosticModel {
    private let name: String
    private let id = UUID()

    var description: String {
        "\(name): \(id.uuidString)"
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
