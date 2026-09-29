import SwiftUI

@MainActor
struct Stage43MultiColumnInterfacesView: View {
    @State private var selectedSection: Stage43CatalogSection? = .all
    @State private var selectedItemID: CatalogItem.ID?
    @State private var preferredVisibility: NavigationSplitViewVisibility = .automatic
    @State private var visibilityChoice: Stage43VisibilityChoice = .automatic
    @State private var selectedCompactTab: Stage43CompactTab = .catalog

    private var filteredItems: [CatalogItem] {
        guard let selectedSection else { return [] }
        return selectedSection.filtered(items: CatalogItem.samples)
    }

    private var selectedItem: CatalogItem? {
        guard let selectedItemID else { return nil }
        return CatalogItem.samples.first(where: { $0.id == selectedItemID })
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $preferredVisibility) {
            List(Stage43CatalogSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationTitle("Sidebar")
        } content: {
            List(selection: $selectedItemID) {
                Section(selectedSection?.title ?? "Select a section") {
                    ForEach(filteredItems) { item in
                        NavigationLink(value: item.id) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                Text(item.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(item.id)
                    }
                }
            }
            .navigationTitle("Catalog")
        } detail: {
            Stage43DetailPanel(item: selectedItem)
        }
        .navigationSplitViewStyle(.balanced)
        .safeAreaInset(edge: .bottom) {
            Stage43ControlPanel(
                selectedSection: $selectedSection,
                selectedItemID: $selectedItemID,
                preferredVisibility: $preferredVisibility,
                visibilityChoice: $visibilityChoice,
                selectedCompactTab: $selectedCompactTab,
                filteredItems: filteredItems
            )
        }
        .onChange(of: selectedSection) { _, newValue in
            guard let newValue else {
                selectedItemID = nil
                return
            }

            let newItems = newValue.filtered(items: CatalogItem.samples)
            if !newItems.contains(where: { $0.id == selectedItemID }) {
                selectedItemID = newItems.first?.id
            }
        }
        .onAppear {
            if selectedItemID == nil {
                selectedItemID = filteredItems.first?.id
            }
            LabLog.event("Stage43MultiColumnInterfacesView onAppear")
        }
    }
}

private enum Stage43CatalogSection: String, CaseIterable, Identifiable, Hashable {
    case all
    case identity
    case state
    case observation

    var id: Self { self }

    var title: String {
        switch self {
        case .all:
            return "All Topics"
        case .identity:
            return "Identity"
        case .state:
            return "State"
        case .observation:
            return "Observation"
        }
    }

    var symbol: String {
        switch self {
        case .all:
            return "square.grid.2x2"
        case .identity:
            return "person.text.rectangle"
        case .state:
            return "switch.2"
        case .observation:
            return "eye"
        }
    }

    func filtered(items: [CatalogItem]) -> [CatalogItem] {
        switch self {
        case .all:
            return items
        case .identity:
            return items.filter { $0.id == "identity" }
        case .state:
            return items.filter { $0.id == "state" }
        case .observation:
            return items.filter { $0.id == "observation" }
        }
    }
}

private enum Stage43CompactTab: String, CaseIterable, Identifiable {
    case catalog
    case detail

    var id: Self { self }
}

private enum Stage43VisibilityChoice: String, CaseIterable, Identifiable {
    case automatic
    case all
    case double
    case detail

    var id: Self { self }

    var label: String {
        switch self {
        case .automatic:
            return "Automatic"
        case .all:
            return "All"
        case .double:
            return "Double"
        case .detail:
            return "Detail"
        }
    }

    var value: NavigationSplitViewVisibility {
        switch self {
        case .automatic:
            return .automatic
        case .all:
            return .all
        case .double:
            return .doubleColumn
        case .detail:
            return .detailOnly
        }
    }
}

private struct Stage43ControlPanel: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @Binding var selectedSection: Stage43CatalogSection?
    @Binding var selectedItemID: CatalogItem.ID?
    @Binding var preferredVisibility: NavigationSplitViewVisibility
    @Binding var visibilityChoice: Stage43VisibilityChoice
    @Binding var selectedCompactTab: Stage43CompactTab
    let filteredItems: [CatalogItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stage 43 - Multi-column interfaces")
                .font(.headline)

            Text("Diagnostics: hSize=\(horizontalSizeClass.debugLabel), vSize=\(verticalSizeClass.debugLabel), requestedVisibility=\(visibilityChoice.label), selectedSection=\(selectedSection?.title ?? "none"), selectedItemID=\(selectedItemID ?? "nil")")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)

            Text("Concept: NavigationSplitView models sidebar/content/detail selection as state. Regular width often shows multiple columns at once; compact width linearizes navigation.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Problem: iPad and macOS need explicit selection state for each column. A single push-style route list is usually not enough.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Prediction: In regular width, section and item selection can stay visible together. In compact width, the same state is reused but presented as a pushed stack.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Column visibility", selection: $visibilityChoice) {
                ForEach(Stage43VisibilityChoice.allCases) { choice in
                    Text(choice.label).tag(choice)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: visibilityChoice) { _, newValue in
                preferredVisibility = newValue.value
            }

            Picker("Compact focus", selection: $selectedCompactTab) {
                ForEach(Stage43CompactTab.allCases) { tab in
                    Text(tab.rawValue.capitalized).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedCompactTab) { _, newValue in
                // Force a visible target in compact demos by steering split view visibility.
                visibilityChoice = newValue == .catalog ? .double : .detail
                preferredVisibility = visibilityChoice.value
            }

            HStack {
                Button("Select first") {
                    selectedItemID = filteredItems.first?.id
                }

                Button("Clear detail") {
                    selectedItemID = nil
                }
            }

            Text("Implementation: Sidebar owns section selection. Content owns item selection. Detail is a pure projection of selected item.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Run: 1) Run on iPhone + iPad previews/simulators. 2) Change section and visibility. 3) Rotate to compact/regular. 4) Verify which state survives layout adaptation.")
                .font(.caption)

            Text("Takeaway: model multi-column selection explicitly; do not infer iPad state from a single push path.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
}

private struct Stage43DetailPanel: View {
    let item: CatalogItem?

    var body: some View {
        Group {
            if let item {
                VStack(alignment: .leading, spacing: 12) {
                    Text(item.title)
                        .font(.largeTitle.bold())
                    Text(item.subtitle)
                        .foregroundStyle(.secondary)

                    Text("Explanation: The detail column reads only selectedItemID-derived data. Changing sidebar selection can invalidate detail if the item is no longer in scope.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
                .navigationTitle("Detail")
            } else {
                ContentUnavailableView(
                    "No Item Selected",
                    systemImage: "sidebar.right",
                    description: Text("Choose a section and item to inspect detail behavior across size classes.")
                )
            }
        }
    }
}

private extension UserInterfaceSizeClass? {
    var debugLabel: String {
        switch self {
        case .compact:
            return "compact"
        case .regular:
            return "regular"
        case nil:
            return "nil"
        @unknown default:
            return "unknown"
        }
    }
}

#Preview("Stage 43 - regular") {
    Stage43MultiColumnInterfacesView()
        .environment(AppRouter())
        .environment(AppUIState())
        .environment(Session())
        .environment(\.itemRepository, PreviewItemRepository(name: "Stage 43 preview"))
}

#Preview("Stage 43 - compact") {
    Stage43MultiColumnInterfacesView()
        .environment(AppRouter())
        .environment(AppUIState())
        .environment(Session())
        .environment(\.itemRepository, PreviewItemRepository(name: "Stage 43 compact"))
        .environment(\.horizontalSizeClass, .compact)
}
