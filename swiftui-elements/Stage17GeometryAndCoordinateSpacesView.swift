import SwiftUI

@MainActor
struct Stage17GeometryAndCoordinateSpacesView: View {
    @State private var useGlobalReadout = false

    init() {
        LabLog.event("Stage17GeometryAndCoordinateSpacesView init")
    }

    var body: some View {
        let _ = LabLog.event("Stage17GeometryAndCoordinateSpacesView body")

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    concept
                    problem
                    prediction
                    sandbox
                    takeaway
                }
                .padding()
            }
            .navigationTitle("Stage 17 Geometry")
        }
    }

    private var concept: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Geometry is measurement, not ownership")
                .font(.headline)

            Text("GeometryReader gives access to size and position during layout. The important part is which coordinate space you ask for: local, global, or a named parent space.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var problem: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Problem")
                .font(.headline)

            Text("Build a sticky section header in a scrolling area and inspect how its frame changes while scrolling.")
                .font(.subheadline)

            Text("UIKit instinct: manually track content offset everywhere. SwiftUI approach: read geometry where needed, then derive visual state from it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var prediction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prediction")
                .font(.headline)

            Text("Before running: when you scroll up, should `minY` in the named scroll space become positive or negative?")
                .font(.subheadline)

            Toggle("Show row telemetry using global space (instead of named scroll space)", isOn: $useGlobalReadout)

            Text("Switching to global space usually makes values harder to reason about because they depend on status/nav bars and ancestor layout.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var sandbox: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Geometry sandbox")
                .font(.headline)

            ScrollView {
                VStack(spacing: 12) {
                    StickyHeader()

                    ForEach(stage17Cards) { card in
                        GeometryReadoutCard(
                            card: card,
                            readoutSpace: useGlobalReadout ? .global : .named(Stage17CoordinateSpace.scroll)
                        )
                    }
                }
                .padding(12)
            }
            .frame(height: 360)
            .coordinateSpace(name: Stage17CoordinateSpace.scroll)
            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .topLeading) {
                Text("Named coordinate space: \(Stage17CoordinateSpace.scroll)")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.2), in: Capsule())
                    .padding(8)
            }

            Text("The sticky behavior is derived from geometry each render pass; we are not imperatively mutating a UIKit scroll view.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var takeaway: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Use `.named(...)` spaces for feature-local reasoning.", systemImage: "checkmark.circle")
            Label("Treat geometry as read-only measurement input.", systemImage: "checkmark.circle")
            Label("Avoid geometry feedback loops for ordinary layout.", systemImage: "checkmark.circle")
        }
        .font(.caption)
        .stageCard()
    }
}

private enum Stage17CoordinateSpace {
    static let scroll = "stage17.scroll"
}

private struct StickyHeader: View {
    init() {
        LabLog.event("StickyHeader init")
    }

    var body: some View {
        GeometryReader { proxy in
            let namedFrame = proxy.frame(in: .named(Stage17CoordinateSpace.scroll))
            let stickyOffset = max(0, -namedFrame.minY)

            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sticky Header")
                        .font(.headline)
                    
                    Text("named minY: \(Int(namedFrame.minY.rounded()))")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.gray.opacity(0.25), lineWidth: 1)
                )
                .offset(y: stickyOffset)
                .zIndex(1)
                
                Rectangle()
                    .fill(.green)
                    .frame(width:48, height: 48)
                    .zIndex(3)
                    .cornerRadius(12)
                    .offset(y: stickyOffset)
                
            }
        }
        .frame(height: 76)
    }
}

private struct GeometryReadoutCard: View {
    let card: Stage17Card
    let readoutSpace: CoordinateSpace

    init(card: Stage17Card, readoutSpace: CoordinateSpace) {
        self.card = card
        self.readoutSpace = readoutSpace
        LabLog.event("GeometryReadoutCard init: \(card.id)")
    }

    var body: some View {
        let _ = LabLog.event("GeometryReadoutCard body: \(card.id)")

        VStack(alignment: .leading, spacing: 8) {
            Text(card.title)
                .font(.subheadline.bold())

            Text(card.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            GeometryReader { proxy in
                let localMinY = proxy.frame(in: .local).minY
                let measuredMinY = proxy.frame(in: readoutSpace).minY

                HStack {
                    Text("local minY: \(Int(localMinY.rounded()))")
                    Spacer()
                    Text("readout minY: \(Int(measuredMinY.rounded()))")
                }
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
            }
            .frame(height: 14)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(card.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(card.tint.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct Stage17Card: Identifiable {
    let id: String
    let title: String
    let description: String
    let tint: Color
}

private let stage17Cards: [Stage17Card] = [
    Stage17Card(
        id: "local",
        title: "Local space",
        description: "Local coordinates are relative to the view itself. They are stable for internal drawing and hit regions.",
        tint: .indigo
    ),
    Stage17Card(
        id: "named",
        title: "Named space",
        description: "Named coordinates are ideal when a feature needs positions relative to a specific scrolling container.",
        tint: .blue
    ),
    Stage17Card(
        id: "global",
        title: "Global space",
        description: "Global coordinates include ancestor effects and are useful for cross-hierarchy alignment, but values shift with chrome.",
        tint: .orange
    ),
    Stage17Card(
        id: "feedback",
        title: "Feedback loop risk",
        description: "If geometry changes state that changes geometry every frame, jitter appears. Keep derived updates minimal and intentional.",
        tint: .pink
    )
]

#Preview("Stage 17 geometry and coordinate spaces") {
    Stage17GeometryAndCoordinateSpacesView()
}
