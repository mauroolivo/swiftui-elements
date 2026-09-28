import Foundation
import SwiftUI

@MainActor
struct Stage36EquatableManualUpdateControlView: View {
    @State private var model = Stage36EquatableLabModel()

    init() {
        LabLog.event("Stage36EquatableManualUpdateControlView init")
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Stage 36 - Equatable and manual update control") {
                    Text("Concept")
                        .font(.headline)
                    Text("`equatable()` is a selective optimization tool. It can let SwiftUI skip a child view update when the child's meaningful inputs are unchanged, even if the parent recomputes. That is useful only when the equality check is cheaper than the skipped work and the equality definition truly matches rendering semantics.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Problem")
                        .font(.headline)
                    Text("When a parent view changes unrelated local state, non-equatable children typically reevaluate their bodies as part of normal diffing. Sometimes that is fine. Sometimes a child performs enough formatting or layout work that skipping identical updates is worthwhile. But manual equality is dangerous: if it ignores a rendering-relevant input, you can freeze stale UI on screen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Prediction")
                        .font(.headline)
                    Text("Before running: if you tap only the parent pulse button, which summary panel should log new work? And when you cycle the accent, which chip should become stale if its equality rule lies about what changed?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Implementation - parent updates vs child equality") {
                    Stage36ControlsCard(model: model)
                    Stage36PlainSummaryPanel(topic: model.selectedTopic, items: model.items)
                    Stage36EquatableSummaryPanel(topic: model.selectedTopic, items: model.items)
                        .equatable()
                }

                Section("Implementation - incorrect manual equality") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("The chip sandbox is pinned outside List rows to avoid row lifecycle noise. There, the plain chip always reflects the latest accent, while the equatable chip intentionally compares only topic and can become stale.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .stageCard()
                }

                Section("Run") {
                    Text("1) Open the debug console and watch the `🧪` logs.")
                    Text("2) Tap \"Bump parent pulse\" several times. The plain summary panel should log new body work each time; the equatable summary panel should stay quiet because its inputs are unchanged.")
                    Text("3) Tap \"Next topic\". Now both summary panels should rerun because a rendering-relevant input changed.")
                    Text("4) Tap \"Cycle accent\". The plain accent chip should update every tap. The broken equatable chip should get stuck until the topic changes, demonstrating stale UI caused by incorrect equality.")
                    Text("5) Optional: profile the pulse button in Instruments. Compare the cost of an equality check against the cost of the skipped child work.")
                }

                Section("Explanation") {
                    Text("`equatable()` does not stop the parent from recomputing. It gives SwiftUI an extra gate for a specific child: if the old and new child values compare equal, SwiftUI can skip updating that subtree. This helps only when the skipped child work is meaningfully more expensive than the equality comparison.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("This is why good state decomposition and focused observation usually come first. If you can avoid broad invalidation by narrowing dependencies or moving expensive work to a better boundary, that is often simpler and safer than writing custom equality logic.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("The broken chip shows the real risk: manual equality is part of rendering correctness. If `==` ignores a property that affects the visual result, SwiftUI may preserve stale output because you told it nothing important changed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Refactor") {
                    Text("Use `equatable()` only after measuring. First ask whether the expensive work belongs in `body`, whether the child depends on too much parent state, and whether a smaller value snapshot or better state ownership would make the optimization unnecessary.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Takeaway") {
                    Text("- `equatable()` is a targeted optimization, not a default SwiftUI pattern.")
                    Text("- Equality must include every input that affects rendering, or you can create stale UI bugs.")
                    Text("- Prefer better dependency boundaries before manual update control.")
                }
            }
            .navigationTitle("Equatable")
        }
        .onAppear {
            LabLog.event("Stage36EquatableManualUpdateControlView onAppear")
        }
        .safeAreaInset(edge: .bottom) {
            Stage36EquatableChipSandbox(topic: model.selectedTopic, accent: model.accentMode)
                .padding(.horizontal)
                .padding(.top, 8)
                .background(.ultraThinMaterial)
        }
    }
}

private struct Stage36EquatableChipSandbox: View {
    let topic: Stage36Topic
    let accent: Stage36AccentMode

    var body: some View {
        let input = Stage36ChipRenderInput(topic: topic, accent: accent)

        VStack(alignment: .leading, spacing: 8) {
            Text("Chip sandbox")
                .font(.headline)

            Text("Cycle accent: plain updates every tap. The gated chip uses an intentionally wrong comparator (topic only), so it can stay stale until topic changes.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Stage36PlainAccentChip(accent: accent)
            Stage36ManualUpdateGate(value: input, areEquivalent: { lhs, rhs in
                lhs.topic == rhs.topic
            }) { accepted in
                Stage36BrokenManualGateAccentChip(accent: accepted.accent)
            }

            Divider()
                .padding(.vertical, 4)

            Text("Redraw stamps (outside List)")
                .font(.headline)
            Text("These stamps are outside List row lifecycle. Pulse/accent updates should increment the plain stamp; the equatable stamp should only increment when topic changes.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Stage36PlainRenderStamp(topic: topic)
            Stage36EquatableRenderStamp(topic: topic)
                .equatable()
        }
    }
}

private struct Stage36ChipRenderInput: Equatable {
    let topic: Stage36Topic
    let accent: Stage36AccentMode
}

private struct Stage36ManualUpdateGate<Value: Equatable, Content: View>: View {
    let value: Value
    let areEquivalent: (Value, Value) -> Bool
    let content: (Value) -> Content

    @State private var acceptedValue: Value

    init(
        value: Value,
        areEquivalent: @escaping (Value, Value) -> Bool,
        @ViewBuilder content: @escaping (Value) -> Content
    ) {
        self.value = value
        self.areEquivalent = areEquivalent
        self.content = content
        _acceptedValue = State(initialValue: value)
    }

    var body: some View {
        content(acceptedValue)
            .onChange(of: value) { _, newValue in
                if !areEquivalent(acceptedValue, newValue) {
                    acceptedValue = newValue
                }
            }
    }
}

@MainActor
@Observable
private final class Stage36EquatableLabModel {
    var parentPulse = 0
    var selectedTopic: Stage36Topic = .identity
    var accentMode: Stage36AccentMode = .blue
    let items: [Stage36LabEntry]

    init(items: [Stage36LabEntry] = Stage36LabEntry.samples) {
        self.items = items
        LabLog.event("Stage36EquatableLabModel init with \(items.count) items")
    }

    deinit {
        LabLog.event("Stage36EquatableLabModel deinit")
    }

    func bumpParentPulse() {
        parentPulse += 1
        LabLog.event("Stage36 parentPulse -> \(parentPulse)")
    }

    func nextTopic() {
        selectedTopic = selectedTopic.next
        LabLog.event("Stage36 selectedTopic -> \(selectedTopic.rawValue)")
    }

    func nextAccent() {
        accentMode = accentMode.next
        LabLog.event("Stage36 accentMode -> \(accentMode.rawValue)")
    }
}

private enum Stage36Topic: String, CaseIterable, Identifiable {
    case identity = "Identity"
    case observation = "Observation"
    case navigation = "Navigation"
    case performance = "Performance"

    var id: Self { self }

    var next: Self {
        let allCases = Self.allCases
        guard let index = allCases.firstIndex(of: self) else { return self }
        return allCases[(index + 1) % allCases.count]
    }
}

private enum Stage36AccentMode: String, CaseIterable, Identifiable {
    case blue = "Blue"
    case green = "Green"
    case orange = "Orange"
    case purple = "Purple"

    var id: Self { self }

    var next: Self {
        let allCases = Self.allCases
        guard let index = allCases.firstIndex(of: self) else { return self }
        return allCases[(index + 1) % allCases.count]
    }

    var color: Color {
        switch self {
        case .blue: .blue
        case .green: .green
        case .orange: .orange
        case .purple: .purple
        }
    }

    var symbol: String {
        switch self {
        case .blue: "drop.fill"
        case .green: "leaf.fill"
        case .orange: "flame.fill"
        case .purple: "sparkles"
        }
    }
}

private struct Stage36LabEntry: Identifiable, Equatable {
    let id: String
    let title: String
    let topics: [Stage36Topic]
    let note: String
    let scoreSeed: Int

    nonisolated static let samples: [Stage36LabEntry] = {
        let topics = Stage36Topic.allCases
        let prefixes = ["Lab", "Guide", "Benchmark", "Case Study", "Prototype", "Review"]
        let notes = [
            "stable ids matter",
            "dependencies stay local",
            "navigation is state",
            "measure before optimizing",
            "observation tracks reads",
            "move work to better boundaries"
        ]

        return (0..<240).map { index in
            let primary = topics[index % topics.count]
            let secondary = topics[(index + 1) % topics.count]
            return Stage36LabEntry(
                id: "stage36-\(index)",
                title: "\(prefixes[index % prefixes.count]) \(primary.rawValue) \(index + 1)",
                topics: index.isMultiple(of: 3) ? [primary, secondary] : [primary],
                note: notes[index % notes.count],
                scoreSeed: (index * 17) % 97
            )
        }
    }()
}

private struct Stage36WorkSummary {
    let matchCount: Int
    let prominentWords: [String]
    let checksum: Int
    let elapsedMilliseconds: Double
}

private enum Stage36SummaryWorkload {
    static func makeSummary(for topic: Stage36Topic, items: [Stage36LabEntry]) -> Stage36WorkSummary {
        let start = Date().timeIntervalSinceReferenceDate
        let matching = items.filter { $0.topics.contains(topic) }
        var histogram: [String: Int] = [:]
        var checksum = 0

        for item in matching {
            let words = (item.title + " " + item.note).lowercased().split(separator: " ")
            for word in words {
                let key = String(word)
                histogram[key, default: 0] += 1
                checksum += key.unicodeScalars.reduce(0) { partialResult, scalar in
                    partialResult + Int(scalar.value % 11)
                }
            }

            checksum += item.scoreSeed * item.topics.count

            for _ in 0..<6 {
                checksum = (checksum &* 31 &+ item.scoreSeed) % 100_000
            }
        }

        let prominentWords = histogram
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .prefix(4)
            .map(\.key)

        return Stage36WorkSummary(
            matchCount: matching.count,
            prominentWords: prominentWords,
            checksum: checksum,
            elapsedMilliseconds: (Date().timeIntervalSinceReferenceDate - start) * 1_000
        )
    }
}

private struct Stage36ControlsCard: View {
    let model: Stage36EquatableLabModel

    init(model: Stage36EquatableLabModel) {
        self.model = model
        LabLog.event("Stage36ControlsCard init")
    }

    var body: some View {
        let _ = LabLog.event("Stage36ControlsCard body")

        VStack(alignment: .leading, spacing: 12) {
            Text("Drive parent and child inputs")
                .font(.headline)

            Text("Parent pulse is intentionally unrelated to the summary panels. Topic is relevant to the summary panels. Accent is relevant only to the chip demo.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Bump parent pulse") {
                    model.bumpParentPulse()
                }

                Spacer()

                Text("Pulse: \(model.parentPulse)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Next topic") {
                    model.nextTopic()
                }

                Spacer()

                Text(model.selectedTopic.rawValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Cycle accent") {
                    model.nextAccent()
                }

                Spacer()

                Text(model.accentMode.rawValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .stageCard()
    }
}

@MainActor
private enum Stage36RenderStampGenerator {
    static var plainValue = 0
    static var equatableValue = 0

    static func nextPlainStamp() -> Int {
        plainValue += 1
        return plainValue
    }

    static func nextEquatableStamp() -> Int {
        equatableValue += 1
        return equatableValue
    }
}

private struct Stage36PlainRenderStamp: View {
    let topic: Stage36Topic

    var body: some View {
        let stamp = Stage36RenderStampGenerator.nextPlainStamp()
        let _ = LabLog.event("Stage36PlainRenderStamp body topic=\(topic.rawValue) stamp=\(stamp)")

        VStack(alignment: .leading, spacing: 6) {
            Text("Plain redraw stamp")
                .font(.headline)
            Text("Body stamp: \(stamp)")
                .font(.subheadline.monospacedDigit())
            Text("This stamp increments whenever this child body reevaluates.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct Stage36EquatableRenderStamp: View, Equatable {
    let topic: Stage36Topic

    static func == (lhs: Stage36EquatableRenderStamp, rhs: Stage36EquatableRenderStamp) -> Bool {
        lhs.topic == rhs.topic
    }

    var body: some View {
        let stamp = Stage36RenderStampGenerator.nextEquatableStamp()
        let _ = LabLog.event("Stage36EquatableRenderStamp body topic=\(topic.rawValue) stamp=\(stamp)")

        VStack(alignment: .leading, spacing: 6) {
            Text("Equatable redraw stamp")
                .font(.headline)
            Text("Body stamp: \(stamp)")
                .font(.subheadline.monospacedDigit())
            Text("Wrapped in `equatable()` with equality based on topic. Pulse updates should not increment this stamp.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct Stage36PlainSummaryPanel: View {
    let topic: Stage36Topic
    let items: [Stage36LabEntry]

    init(topic: Stage36Topic, items: [Stage36LabEntry]) {
        self.topic = topic
        self.items = items
        LabLog.event("Stage36PlainSummaryPanel init")
    }

    var body: some View {
        let summary = Stage36SummaryWorkload.makeSummary(for: topic, items: items)
        let _ = LabLog.event("Stage36PlainSummaryPanel body topic=\(topic.rawValue) took \(String(format: "%.2f", summary.elapsedMilliseconds)) ms")

        Stage36SummaryCard(
            title: "Plain child view",
            subtitle: "This body reruns whenever the parent reevaluates, even if the child inputs stayed the same.",
            summary: summary,
            dependencyNote: "No manual update gate"
        )
    }
}

private struct Stage36EquatableSummaryPanel: View, Equatable {
    let topic: Stage36Topic
    let items: [Stage36LabEntry]

    init(topic: Stage36Topic, items: [Stage36LabEntry]) {
        self.topic = topic
        self.items = items
        LabLog.event("Stage36EquatableSummaryPanel init")
    }

    static func == (lhs: Stage36EquatableSummaryPanel, rhs: Stage36EquatableSummaryPanel) -> Bool {
        lhs.topic == rhs.topic && lhs.items == rhs.items
    }

    var body: some View {
        let summary = Stage36SummaryWorkload.makeSummary(for: topic, items: items)
        let _ = LabLog.event("Stage36EquatableSummaryPanel body topic=\(topic.rawValue) took \(String(format: "%.2f", summary.elapsedMilliseconds)) ms")

        Stage36SummaryCard(
            title: "Equatable child view",
            subtitle: "Wrapped in `equatable()`. Parent pulse still recomputes the parent, but SwiftUI can skip this child when its meaningful inputs compare equal.",
            summary: summary,
            dependencyNote: "Equality inputs: topic + items"
        )
    }
}

private struct Stage36SummaryCard: View {
    let title: String
    let subtitle: String
    let summary: Stage36WorkSummary
    let dependencyNote: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline) {
                Text("Matches")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(summary.matchCount)")
                    .font(.subheadline.monospacedDigit())
            }

            HStack(alignment: .firstTextBaseline) {
                Text("Transform time")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.2f ms", summary.elapsedMilliseconds))
                    .font(.subheadline.monospacedDigit())
            }

            HStack(alignment: .firstTextBaseline) {
                Text("Checksum")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(summary.checksum)")
                    .font(.subheadline.monospacedDigit())
            }

            Text("Top words: \(summary.prominentWords.joined(separator: ", "))")
                .font(.caption)

            Text(dependencyNote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct Stage36PlainAccentChip: View {
    let accent: Stage36AccentMode

    var body: some View {
        let _ = LabLog.event("Stage36PlainAccentChip body accent=\(accent.rawValue)")

        Label("Plain chip: \(accent.rawValue)", systemImage: accent.symbol)
            .font(.subheadline.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(.white)
            .background(accent.color.gradient, in: Capsule())
    }
}

private struct Stage36BrokenManualGateAccentChip: View {
    let accent: Stage36AccentMode

    var body: some View {
        let _ = LabLog.event("Stage36BrokenManualGateAccentChip body accent=\(accent.rawValue)")

        VStack(alignment: .leading, spacing: 6) {
            Label("Broken gated chip: \(accent.rawValue)", systemImage: accent.symbol)
                .font(.subheadline.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(.white)
                .background(accent.color.gradient, in: Capsule())

            Text("Comparator ignores accent updates, so accent-only changes are dropped.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Stage 36 - Equatable") {
    Stage36EquatableManualUpdateControlView()
}
