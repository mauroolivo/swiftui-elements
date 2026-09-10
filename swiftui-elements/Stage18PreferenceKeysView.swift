import SwiftUI

@MainActor
struct Stage18PreferenceKeysView: View {
    @State private var selectedTab: Stage18Tab = .identity
    @State private var transformedChipWidths: [Stage18Tab: CGFloat] = [:]

    init() {
        LabLog.event("Stage18PreferenceKeysView init")
    }

    var body: some View {
        let _ = LabLog.event("Stage18PreferenceKeysView body")

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
            .navigationTitle("Stage 18 Preferences")
        }
    }

    private var concept: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PreferenceKey is child → parent communication")
                .font(.headline)

            Text("Environment flows downward. Preference values flow upward. That makes PreferenceKey useful when a child needs to report measurement or visibility back to an ancestor without direct coupling.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var problem: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Problem")
                .font(.headline)

            Text("Build a segmented control where each chip reports its bounds upward so the parent can draw the selected highlight and summarize the measurements.")
                .font(.subheadline)

            Text("UIKit instinct: store references to child views or manually compute frames from outside. SwiftUI approach: let children publish preferences and let the ancestor react.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var prediction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prediction")
                .font(.headline)

            Text("Before you tap a chip: does the parent know the child frame because it reaches into the child, or because the child reports a preference that bubbles up?")
                .font(.subheadline)

            Text("Also predict what happens if the selection changes: the highlight should move because the ancestor re-renders with the new preference data, not because the child imperatively moved anything.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var sandbox: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preference sandbox")
                .font(.headline)

            Text("The chips below send their bounds upward. A small transformPreference step adds a little buffer to the reported widths before the parent reads them.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Stage18PreferenceStrip(selection: $selectedTab)
                .onPreferenceChange(Stage18ChipWidthPreferenceKey.self) { widths in
                    transformedChipWidths = widths
                    LabLog.event("Stage18PreferenceKeysView received width preferences for \(widths.count) chip(s)")
                }

            Stage18TelemetryPanel(
                selectedTab: selectedTab,
                widths: transformedChipWidths
            )
        }
        .stageCard()
    }

    private var takeaway: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Preferences communicate upward; they do not replace ownership.", systemImage: "arrow.up.circle")
            Label("Use anchors when the parent needs geometry from a child.", systemImage: "square.dashed")
            Label("Use transformPreference to normalize or enrich child-reported values.", systemImage: "slider.horizontal.3")
        }
        .font(.caption)
        .stageCard()
    }
}

private enum Stage18Tab: String, CaseIterable, Identifiable, Hashable {
    case identity = "Identity"
    case state = "State"
    case observation = "Observation"

    var id: Self { self }
}

private struct Stage18PreferenceStrip: View {
    @Binding var selection: Stage18Tab

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Stage18Tab.allCases) { tab in
                Stage18PreferenceChip(
                    tab: tab,
                    isSelected: tab == selection,
                    action: {
                        selection = tab
                        LabLog.event("Stage18PreferenceKeysView selected \(tab.rawValue)")
                    }
                )
            }
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .transformPreference(Stage18ChipWidthPreferenceKey.self) { widths in
            widths = widths.mapValues { $0 + 12 }
        }
        .backgroundPreferenceValue(Stage18ChipBoundsPreferenceKey.self) { anchors in
            GeometryReader { proxy in
                if let anchor = anchors[selection] {
                    let rect = proxy[anchor]

                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.16))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

private struct Stage18PreferenceChip: View {
    let tab: Stage18Tab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tab.rawValue)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor.opacity(0.22) : Color.secondary.opacity(0.12))
                )
                .anchorPreference(key: Stage18ChipBoundsPreferenceKey.self, value: .bounds) { [tab: $0] }
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: Stage18ChipWidthPreferenceKey.self, value: [tab: proxy.size.width])
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

private struct Stage18TelemetryPanel: View {
    let selectedTab: Stage18Tab
    let widths: [Stage18Tab: CGFloat]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What the parent learned")
                .font(.headline)

            Text("Selected tab: \(selectedTab.rawValue)")
                .font(.subheadline)

            Text("Reported chip count: \(widths.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Selected chip width after transformPreference: \(formattedWidth(for: selectedTab)) pt")
                .font(.caption.monospaced())

            Text("Widest transformed chip: \(formattedWidestWidth)")
                .font(.caption.monospaced())

            Text("The parent does not own these measurements. It receives them from children, then decides what to do with them.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private func formattedWidth(for tab: Stage18Tab) -> String {
        guard let width = widths[tab] else { return "pending" }
        return String(Int(width.rounded()))
    }

    private var formattedWidestWidth: String {
        guard let widest = widths.values.max() else { return "pending" }
        return String(Int(widest.rounded()))
    }
}

private struct Stage18ChipBoundsPreferenceKey: PreferenceKey {
    static var defaultValue: [Stage18Tab: Anchor<CGRect>] { [:] }

    static func reduce(value: inout [Stage18Tab: Anchor<CGRect>], nextValue: () -> [Stage18Tab: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct Stage18ChipWidthPreferenceKey: PreferenceKey {
    static var defaultValue: [Stage18Tab: CGFloat] { [:] }

    static func reduce(value: inout [Stage18Tab: CGFloat], nextValue: () -> [Stage18Tab: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

#Preview("Stage 18 preference keys") {
    Stage18PreferenceKeysView()
}
