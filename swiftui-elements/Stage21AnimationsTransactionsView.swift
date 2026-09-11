import SwiftUI

@MainActor
struct Stage21AnimationsTransactionsView: View {
    @State private var isExpanded = false
    @State private var selectedFilter: Stage21Filter = .all
    @State private var suppressCountAnimation = false
    @State private var selectedRoute: Stage21Route = .overview

    private let items = Stage21DemoItem.samples

    init() {
        LabLog.event("Stage21AnimationsTransactionsView init")
    }

    var body: some View {
        let _ = LabLog.event("Stage21AnimationsTransactionsView body")

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    myView
                    concept
                    problem
                    prediction
                    implementation
                    refactor
                    takeaway
                }
                .padding()
            }
            .navigationTitle("Stage 21 Animation")
        }
    }

    private var concept: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Animation follows state changes")
                .font(.headline)

            Text("SwiftUI does not animate because a view re-ran its body. It animates when a state mutation happens inside an animation transaction, or when a subtree opts in with an animation tied to a specific value.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stage21Card()
    }

    private var problem: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Problem")
                .font(.headline)

            Text("A card should expand smoothly, a filtered list should animate insertions and removals, and a route-like preview should move without every label in the subtree inheriting the same motion.")
                .font(.subheadline)

            Text("UIKit instinct: sprinkle implicit animation everywhere or wrap the whole screen in one giant animation block. SwiftUI asks a more precise question: which mutation should animate, and which parts should stay still?")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stage21Card()
    }

    private var prediction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prediction")
                .font(.headline)

            Text("Before tapping anything: which pieces will animate if we toggle expansion with withAnimation, switch filters with an animation tied to the filter state, and disable the count badge's transaction animation?")
                .font(.subheadline)

            Text("Also predict whether the route preview will animate when the selected route changes, even though it is not using NavigationStack yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stage21Card()
    }

    private var implementation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Implementation sandbox")
                .font(.headline)

            Stage21ExpansionPanel(isExpanded: $isExpanded)

            Stage21FilterPanel(
                items: items,
                selectedFilter: $selectedFilter,
                suppressCountAnimation: $suppressCountAnimation
            )

            Stage21RoutePreview(selectedRoute: $selectedRoute)

            Text("The three controls demonstrate different animation boundaries: explicit withAnimation for a discrete interaction, animation(value:) for a subtree that depends on a specific value, and transaction(...) to suppress animation for a child region.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stage21Card()
    }

    private var refactor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Refactor lens")
                .font(.headline)

            Text("If every mutation is wrapped in withAnimation, the code becomes noisy. If every view uses animation(_:), motion becomes mysterious. The better split is: animate the mutation where the interaction occurs, and selectively opt subtrees in or out when they need different behavior.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stage21Card()
    }

    private var takeaway: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Use withAnimation when the interaction itself should drive the motion.", systemImage: "sparkles")
            Label("Use animation(_:value:) when a subtree should respond to one specific changing value.", systemImage: "arrow.triangle.2.circlepath")
            Label("Use transaction to override or suppress animation for a child region.", systemImage: "pause.circle")
        }
        .font(.caption)
        .stage21Card()
    }
}

private struct Stage21ExpansionPanel: View {
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Explicit expansion")
                        .font(.subheadline.bold())

                    Text("The toggle action is the animation boundary here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    withAnimation(.snappy(duration: 0.28)) {
                        isExpanded.toggle()
                    }
                    LabLog.event("Stage21ExpansionPanel toggled to \(isExpanded)")
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.headline.weight(.semibold))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Collapse card" : "Expand card")
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text("When the card expands, only the expansion state should animate. The content is a new structural branch, so its insertion/removal transition is part of the same state change.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Label("Body recompute", systemImage: "repeat")
                        Spacer()
                        Label("Layout change", systemImage: "ruler")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                //.transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.snappy(duration: 0.28), value: isExpanded)
        .stage21Card()
    }
}

private struct Stage21FilterPanel: View {
    let items: [Stage21DemoItem]
    @Binding var selectedFilter: Stage21Filter
    @Binding var suppressCountAnimation: Bool

    private var visibleItems: [Stage21DemoItem] {
        items.filter { selectedFilter == .all || $0.filter == selectedFilter }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Filtered list transition")
                        .font(.subheadline.bold())

                    Text("The list animates because the filtered array changes, not because the whole view is re-rendered.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(visibleItems.count) visible")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
                    .animation(.snappy(duration: 0.2), value: visibleItems.count)
                    .transaction { transaction in
                        if suppressCountAnimation {
                            transaction.animation = nil
                        }
                    }
            }

            Toggle("Suppress count badge animation with transaction", isOn: $suppressCountAnimation)
                .font(.caption)

            HStack(spacing: 8) {
                ForEach(Stage21Filter.allCases) { filter in
                    Stage21ChipButton(
                        title: filter.rawValue,
                        isSelected: filter == selectedFilter,
                        accent: filter.tint,
                        action: {
                            select(filter)
                        }
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(visibleItems) { item in
                    Stage21ListRow(item: item)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .leading)),
                            removal: .opacity.combined(with: .scale(scale: 0.96))
                        ))

                    if item.id != visibleItems.last?.id {
                        Divider()
                    }
                }
            }
            .animation(.smooth(duration: 0.24), value: visibleItems)

            Text("Toggling the filter changes the visible collection. Each row has a stable identity, so SwiftUI can animate insertion/removal instead of rebuilding the entire section.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onChange(of: selectedFilter) { _, newValue in
            LabLog.event("Stage21FilterPanel selected filter changed to \(newValue.rawValue)")
        }
        .stage21Card()
    }

    private func select(_ filter: Stage21Filter) {
        guard filter != selectedFilter else { return }
        withAnimation(.smooth(duration: 0.24)) {
            selectedFilter = filter
        }
    }
}

private struct Stage21RoutePreview: View {
    @Binding var selectedRoute: Stage21Route

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Navigation-adjacent animation")
                    .font(.subheadline.bold())

                Text("This is not a NavigationStack yet. It is a route-like state change that previews how a selection could feel before the real navigation model arrives.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(Stage21Route.allCases) { route in
                    Stage21ChipButton(
                        title: route.rawValue,
                        isSelected: route == selectedRoute,
                        accent: route.tint,
                        action: {
                            select(route)
                        }
                    )
                }
            }

            routeDetail(for: selectedRoute)
                .id(selectedRoute)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
                .animation(.snappy(duration: 0.24), value: selectedRoute)

            Text("The same rule will apply later when actual routes drive a NavigationStack path: the state change is what matters, not the visual component that reads it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stage21Card()
    }

    private func select(_ route: Stage21Route) {
        guard route != selectedRoute else { return }
        withAnimation(.snappy(duration: 0.24)) {
            selectedRoute = route
        }
        LabLog.event("Stage21RoutePreview selected route \(route.rawValue)")
    }

    private func routeDetail(for route: Stage21Route) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(route.rawValue, systemImage: route.systemImage)
                .font(.headline)

            Text(route.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(route.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

@ViewBuilder
private var myView: some View {
    
        Text("Hello, World1!")
            .padding()
        Text("Hello, World2!")
            .padding()
    
}

private struct Stage21ListRow: View {
    let item: Stage21DemoItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(item.filter.tint)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))

                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(item.filter.rawValue)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(item.filter.tint)
        }
    }
}

private struct Stage21ChipButton: View {
    let title: String
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(
                    Capsule()
                        .fill(isSelected ? accent : .clear)
                )
                .overlay {
                    Capsule()
                        .strokeBorder(isSelected ? .clear : accent.opacity(0.25), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private enum Stage21Filter: String, CaseIterable, Identifiable, Hashable {
    case all = "All"
    case favorites = "Favorites"
    case archived = "Archived"

    var id: Self { self }

    var tint: Color {
        switch self {
        case .all: return .accentColor
        case .favorites: return .yellow
        case .archived: return .secondary
        }
    }
}

private enum Stage21Route: String, CaseIterable, Identifiable, Hashable {
    case overview = "Overview"
    case detail = "Detail"
    case history = "History"

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .overview: return "rectangle.grid.2x2"
        case .detail: return "doc.text.magnifyingglass"
        case .history: return "clock.arrow.circlepath"
        }
    }

    var detail: String {
        switch self {
        case .overview:
            return "A selection change is enough to animate the preview. When we introduce real navigation, the same lightweight route value can drive a stack path."
        case .detail:
            return "Detail-like state often wants a stronger motion cue than a plain opacity change. That's why route changes are useful to study before we move into NavigationStack."
        case .history:
            return "History-style routes are a good reminder that a route is state, not a screen instance. The animation should follow the state mutation, not the other way around."
        }
    }

    var tint: Color {
        switch self {
        case .overview: return .blue
        case .detail: return .indigo
        case .history: return .orange
        }
    }
}

private struct Stage21DemoItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let filter: Stage21Filter

    static let samples: [Stage21DemoItem] = [
        Stage21DemoItem(id: "rendering", title: "Rendering model", subtitle: "A view value is transient, but state changes can still animate the transition between values.", filter: .favorites),
        Stage21DemoItem(id: "identity", title: "Identity", subtitle: "Stable IDs let SwiftUI match old and new rows during insertion and removal.", filter: .favorites),
        Stage21DemoItem(id: "transactions", title: "Transactions", subtitle: "A subtree can opt out of inherited animation for one specific update.", filter: .archived),
        Stage21DemoItem(id: "navigation", title: "Navigation", subtitle: "Route-like state changes will later become path mutations in a real stack.", filter: .all)
    ]
}

private struct Stage21CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }
}

private extension View {
    func stage21Card() -> some View {
        modifier(Stage21CardModifier())
    }
}

#Preview("Stage 21 animations and transactions") {
    Stage21AnimationsTransactionsView()
}
