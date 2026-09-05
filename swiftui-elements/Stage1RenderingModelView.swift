import SwiftUI

@MainActor
struct Stage1RenderingModelView: View {
    @State private var count = 0
    @State private var showDetails = true

    init() {
        LabLog.event("Stage1RenderingModelView init")
    }

    var body: some View {
        let _ = LabLog.event("Stage1RenderingModelView body")

        VStack(alignment: .leading, spacing: 12) {
            Text("Stage 1 - Rendering model")
                .font(.title3.bold())

            Text("View values are lightweight descriptions. Frequent body calls do not imply expensive UI recreation.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Increment") { count += 1 }
                Button(showDetails ? "Hide child" : "Show child") { showDetails.toggle() }
            }

            Text("Count: \(count)")

            if showDetails {
                Stage1ChildProbe(value: count)
            }
        }
        .padding()
        .stageCard()
        .onAppear { LabLog.event("Stage1RenderingModelView onAppear") }
        .onDisappear { LabLog.event("Stage1RenderingModelView onDisappear") }
    }
}

private struct Stage1ChildProbe: View {
    let value: Int

    init(value: Int) {
        self.value = value
        LabLog.event("Stage1ChildProbe init value=\(value)")
    }

    var body: some View {
        let _ = LabLog.event("Stage1ChildProbe body value=\(value)")

        Text("Child value: \(value)")
            .font(.subheadline)
            .padding(8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .onAppear { LabLog.event("Stage1ChildProbe onAppear") }
            .onDisappear { LabLog.event("Stage1ChildProbe onDisappear") }
    }
}

#Preview("Stage 1") {
    Stage1RenderingModelView()
}
