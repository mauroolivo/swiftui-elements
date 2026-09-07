import SwiftUI

@MainActor
struct Stage16LayoutBeyondStacksView: View {
    @State private var proposedWidth: Double = 320
    @State private var minimumCardWidth: Double = 140
    @State private var spacing: Double = 12

    init() {
        LabLog.event("Stage16LayoutBeyondStacksView init")
    }

    var body: some View {
        let _ = LabLog.event("Stage16LayoutBeyondStacksView body")

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    concept
                    controls
                    summary
                    sandbox
                }
                .padding()
            }
            .navigationTitle("Stage 16 Layout")
        }
    }

    private var concept: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A custom layout decides measurement and placement")
                .font(.headline)

            Text("The blue frame is the parent proposal. The layout divides that width into columns, proposes a card width to each child, asks each child for its size, then places the cards row by row.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Proposal controls")
                .font(.headline)

            LabeledContent("Container width", value: "\(Int(proposedWidth)) pt")
            Slider(value: $proposedWidth, in: 220 ... 420, step: 1)

            LabeledContent("Minimum card width", value: "\(Int(minimumCardWidth)) pt")
            Slider(value: $minimumCardWidth, in: 100 ... 220, step: 1)

            LabeledContent("Spacing", value: "\(Int(spacing)) pt")
            Slider(value: $spacing, in: 4 ... 24, step: 1)

            Text("Change the proposal width first, then the minimum card width. Watch how column count changes even though the child views themselves did not become Auto Layout constraints.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var summary: some View {
        let metrics = AdaptiveCardLayout.metrics(
            availableWidth: proposedWidth,
            minimumItemWidth: minimumCardWidth,
            spacing: spacing,
            itemCount: stage16Lessons.count
        )

        return VStack(alignment: .leading, spacing: 6) {
            Label("Columns: \(metrics.columns)", systemImage: "square.grid.2x2")
            Text("Effective card width: \(Int(metrics.itemWidth.rounded())) pt")
                .font(.caption)
            Text("Rows for this data set: \(metrics.rows)")
                .font(.caption)
            Text("Parent proposes size → child chooses size → parent places child. That is the SwiftUI layout contract.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var sandbox: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adaptive card layout sandbox")
                .font(.headline)

            AdaptiveCardLayout(
                minimumItemWidth: minimumCardWidth,
                spacing: spacing
            ) {
                ForEach(stage16Lessons) { lesson in
                    LessonCard(lesson: lesson)
                }
            }
            .frame(width: proposedWidth, alignment: .topLeading)
            .padding(12)
            .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .topLeading) {
                Text("Parent proposal: \(Int(proposedWidth)) pt")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.2), in: Capsule())
                    .padding(8)
            }

            Text("The layout uses equal-width columns but lets each card report its own height. That is why rows align while card heights still vary with content.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .stageCard()
    }
}

private struct AdaptiveCardLayout: Layout {
    let minimumItemWidth: CGFloat
    let spacing: CGFloat

    init(minimumItemWidth: Double, spacing: Double) {
        self.minimumItemWidth = minimumItemWidth
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let availableWidth = max(proposal.width ?? minimumItemWidth, minimumItemWidth)
        let metrics = Self.metrics(
            availableWidth: availableWidth,
            minimumItemWidth: minimumItemWidth,
            spacing: spacing,
            itemCount: subviews.count
        )

        let rowHeights = rowHeights(for: subviews, itemWidth: metrics.itemWidth, columns: metrics.columns)
        let totalHeight = rowHeights.reduce(0, +) + spacing * CGFloat(max(rowHeights.count - 1, 0))

        LabLog.event("AdaptiveCardLayout sizeThatFits width=\(Int(availableWidth.rounded())) columns=\(metrics.columns) rows=\(rowHeights.count)")
        return CGSize(width: availableWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let metrics = Self.metrics(
            availableWidth: bounds.width,
            minimumItemWidth: minimumItemWidth,
            spacing: spacing,
            itemCount: subviews.count
        )

        let rowHeights = rowHeights(for: subviews, itemWidth: metrics.itemWidth, columns: metrics.columns)

        var x = bounds.minX
        var y = bounds.minY

        for index in subviews.indices {
            let row = index / metrics.columns
            let column = index % metrics.columns
            let cellProposal = ProposedViewSize(width: metrics.itemWidth, height: nil)
            let size = subviews[index].sizeThatFits(cellProposal)

            if column == 0 {
                x = bounds.minX
            }

            subviews[index].place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: metrics.itemWidth, height: size.height)
            )

            x += metrics.itemWidth + spacing

            if column == metrics.columns - 1 || index == subviews.count - 1 {
                y += rowHeights[row] + spacing
            }
        }

        LabLog.event("AdaptiveCardLayout placeSubviews width=\(Int(bounds.width.rounded())) columns=\(metrics.columns)")
    }

    private func rowHeights(for subviews: Subviews, itemWidth: CGFloat, columns: Int) -> [CGFloat] {
        guard !subviews.isEmpty else { return [] }

        var heights: [CGFloat] = []

        for start in stride(from: 0, to: subviews.count, by: columns) {
            let end = min(start + columns, subviews.count)
            let rowHeight = subviews[start..<end]
                .map { $0.sizeThatFits(ProposedViewSize(width: itemWidth, height: nil)).height }
                .max() ?? 0
            heights.append(rowHeight)
        }

        return heights
    }

    static func metrics(
        availableWidth: CGFloat,
        minimumItemWidth: CGFloat,
        spacing: CGFloat,
        itemCount: Int
    ) -> LayoutMetrics {
        let usableWidth = max(availableWidth, minimumItemWidth)
        let tentativeColumns = Int((usableWidth + spacing) / (minimumItemWidth + spacing))
        let columns = max(tentativeColumns, 1)
        let totalSpacing = spacing * CGFloat(max(columns - 1, 0))
        let itemWidth = (usableWidth - totalSpacing) / CGFloat(columns)
        let rows = itemCount == 0 ? 0 : Int(ceil(Double(itemCount) / Double(columns)))

        return LayoutMetrics(columns: columns, rows: rows, itemWidth: itemWidth)
    }

    struct LayoutMetrics {
        let columns: Int
        let rows: Int
        let itemWidth: CGFloat
    }
}

private struct LessonCard: View {
    let lesson: Stage16Lesson

    init(lesson: Stage16Lesson) {
        self.lesson = lesson
        LabLog.event("LessonCard init: \(lesson.id)")
    }

    var body: some View {
        let _ = LabLog.event("LessonCard body: \(lesson.id)")

        VStack(alignment: .leading, spacing: 8) {
            Text(lesson.title)
                .font(.headline)

            Text(lesson.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text(lesson.footnote)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(lesson.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(lesson.tint.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct Stage16Lesson: Identifiable {
    let id: String
    let title: String
    let summary: String
    let footnote: String
    let tint: Color
}

private let stage16Lessons: [Stage16Lesson] = [
    Stage16Lesson(
        id: "proposal",
        title: "Proposal",
        summary: "The parent does not dictate an exact final frame. It proposes a size to the custom layout.",
        footnote: "Think negotiation, not constraints.",
        tint: .blue
    ),
    Stage16Lesson(
        id: "measurement",
        title: "Measurement",
        summary: "The layout asks each child what size it wants for the proposed card width, so text length changes card height.",
        footnote: "Children choose size.",
        tint: .green
    ),
    Stage16Lesson(
        id: "placement",
        title: "Placement",
        summary: "After measuring, the layout places every card row by row inside its bounds.",
        footnote: "Placement is separate from measurement.",
        tint: .orange
    ),
    Stage16Lesson(
        id: "adaptivity",
        title: "Adaptivity",
        summary: "Reducing the proposal width can change the number of columns even though the data and child views stay the same.",
        footnote: "Same children, different arrangement.",
        tint: .purple
    ),
    Stage16Lesson(
        id: "identity",
        title: "Identity still matters",
        summary: "Layout decides geometry, not view identity. State lifetime is still governed by SwiftUI identity rules from earlier stages.",
        footnote: "Layout is not lifetime.",
        tint: .pink
    )
]

#Preview("Stage 16 layout beyond stacks") {
    Stage16LayoutBeyondStacksView()
}