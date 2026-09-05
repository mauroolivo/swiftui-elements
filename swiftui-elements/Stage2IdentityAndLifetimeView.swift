import SwiftUI

@MainActor
struct Stage2IdentityAndLifetimeView: View {
    @State private var useBranchA = true
    @State private var useUnstableID = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stage 2 - Identity and lifetime")
                .font(.title3.bold())

            Toggle("Use branch A", isOn: $useBranchA)
            Toggle("Use unstable .id(UUID())", isOn: $useUnstableID)

            Group {
                if useBranchA {
                    Stage2CounterCard(title: "Branch A")
                        .id(useUnstableID ? AnyHashable(UUID()) : AnyHashable("stable-counter"))
                } else {
                    Stage2CounterCard(title: "Branch B")
                        .id(useUnstableID ? AnyHashable(UUID()) : AnyHashable("stable-counter"))
                }
            }

            Text("Stable id preserves @State. UUID id forces reset each update.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .stageCard()
    }
}

private struct Stage2CounterCard: View {
    let title: String
    @State private var localCount = 0

    init(title: String) {
        self.title = title
        LabLog.event("Stage2CounterCard init \(title)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text("Local count: \(localCount)")
            Button("Increment local") { localCount += 1 }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview("Stage 2") {
    Stage2IdentityAndLifetimeView()
}
