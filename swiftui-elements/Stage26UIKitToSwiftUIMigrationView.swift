import Observation
import SwiftUI
import UIKit

private enum Stage26MigrationPhase: String, CaseIterable, Identifiable {
    case legacyUIKitTable = "1) Legacy UIKit table"
    case swiftUIRowsInUIKit = "2) SwiftUI row in UITableView"
    case hostedSwiftUIScreen = "3) SwiftUI feature hosted by UIKit"
    case swiftUINavigationOwnership = "4) SwiftUI NavigationStack owns nav"

    var id: Self { self }

    var summary: String {
        switch self {
        case .legacyUIKitTable:
            "UIKit owns view hierarchy, table rendering, and navigation."
        case .swiftUIRowsInUIKit:
            "Keep UITableView + diffable data source, but migrate row rendering to SwiftUI."
        case .hostedSwiftUIScreen:
            "Move the full feature UI to SwiftUI while UIKit still owns presentation/navigation."
        case .swiftUINavigationOwnership:
            "Move feature navigation to SwiftUI NavigationStack while keeping the same shared model."
        }
    }
}

@MainActor
struct Stage26UIKitToSwiftUIMigrationView: View {
    @State private var selectedPhase: Stage26MigrationPhase = .legacyUIKitTable
    @State private var store = Stage26CatalogStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Stage 26 - UIKit to SwiftUI incremental migration")
                    .font(.title3.bold())

                Text("We keep one shared feature model and migrate the presentation boundary in small steps: UIKit table -> SwiftUI rows in UIKit -> hosted SwiftUI feature -> SwiftUI NavigationStack.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Prediction")
                    .font(.headline)

                Text("Switch phases, then toggle favorites and search. Which state survives phase changes, and when does navigation ownership actually move from UIKit to SwiftUI?")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Migration phase", selection: $selectedPhase) {
                    ForEach(Stage26MigrationPhase.allCases) { phase in
                        Text(phase.rawValue).tag(phase)
                    }
                }
                .pickerStyle(.menu)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Active phase")
                        .font(.subheadline.bold())
                    Text(selectedPhase.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Shared store state: query=\(store.searchQuery.isEmpty ? "empty" : store.searchQuery), favorites=\(store.favoriteIDs.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Button("Reset shared store") {
                        store.resetDemoState()
                    }
                    .buttonStyle(.bordered)
                }
                .stageCard()

                switch selectedPhase {
                case .legacyUIKitTable, .swiftUIRowsInUIKit, .hostedSwiftUIScreen:
                    Stage26MigrationHostSurface(phase: selectedPhase, store: store)
                        .frame(height: 520)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.quaternary)
                        }
                        .id(selectedPhase)
                case .swiftUINavigationOwnership:
                    Stage26PureSwiftUINavigationExercise(store: store)
                }

                Text("Takeaway: migration is mostly about moving ownership boundaries, not rewriting domain/service code.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

private struct Stage26MigrationHostSurface: UIViewControllerRepresentable {
    let phase: Stage26MigrationPhase
    let store: Stage26CatalogStore

    func makeUIViewController(context: Context) -> Stage26MigrationNavigationController {
        Stage26MigrationNavigationController(phase: phase, store: store)
    }

    func updateUIViewController(_ uiViewController: Stage26MigrationNavigationController, context: Context) {
        uiViewController.applyPhase(phase)
    }
}

@MainActor
private final class Stage26MigrationNavigationController: UINavigationController {
    private let migrationCoordinator: Stage26MigrationCoordinator
    private var currentPhase: Stage26MigrationPhase

    init(phase: Stage26MigrationPhase, store: Stage26CatalogStore) {
        self.migrationCoordinator = Stage26MigrationCoordinator(store: store)
        self.currentPhase = phase

        let initialRoot = migrationCoordinator.makeRoot(for: phase)
        super.init(rootViewController: initialRoot)
        migrationCoordinator.attach(navigationController: self)
        navigationBar.prefersLargeTitles = false
        LabLog.event("Stage26MigrationNavigationController init for \(phase.rawValue)")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyPhase(_ phase: Stage26MigrationPhase) {
        guard phase != currentPhase else { return }
        currentPhase = phase

        let root = migrationCoordinator.makeRoot(for: phase)
        setViewControllers([root], animated: false)
        LabLog.event("Stage26MigrationNavigationController applied \(phase.rawValue)")
    }
}

@MainActor
private final class Stage26MigrationCoordinator {
    private weak var navigationController: UINavigationController?
    private let store: Stage26CatalogStore

    init(store: Stage26CatalogStore) {
        self.store = store
        LabLog.event("Stage26MigrationCoordinator init")
    }

    func attach(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func makeRoot(for phase: Stage26MigrationPhase) -> UIViewController {
        switch phase {
        case .legacyUIKitTable:
            makeLegacyList(rendering: .uikitCell)
        case .swiftUIRowsInUIKit:
            makeLegacyList(rendering: .swiftUIRow)
        case .hostedSwiftUIScreen:
            makeHostedSwiftUIRoot()
        case .swiftUINavigationOwnership:
            UIViewController()
        }
    }

    private func makeLegacyList(rendering: Stage26LegacyListViewController.Rendering) -> UIViewController {
        let controller = Stage26LegacyListViewController(store: store, rendering: rendering)
        controller.onOpenDetail = { [weak navigationController] item in
            let detail = Stage26ItemDetailViewController(item: item, source: rendering == .uikitCell ? "UIKit table" : "UIKit table + SwiftUI row")
            navigationController?.pushViewController(detail, animated: true)
        }
        return controller
    }

    private func makeHostedSwiftUIRoot() -> UIViewController {
        let controller = Stage26UIKitHostRootViewController(store: store)
        controller.onOpenDetail = { [weak navigationController] item in
            let detail = Stage26ItemDetailViewController(item: item, source: "Hosted SwiftUI feature")
            navigationController?.pushViewController(detail, animated: true)
        }
        return controller
    }
}

@MainActor
private final class Stage26LegacyListViewController: UIViewController {
    enum Rendering {
        case uikitCell
        case swiftUIRow
    }

    private let store: Stage26CatalogStore
    private let rendering: Rendering
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let searchBar = UISearchBar(frame: .zero)

    private var dataSource: UITableViewDiffableDataSource<Int, Stage26CatalogItem.ID>!
    private var visibleItemByID: [Stage26CatalogItem.ID: Stage26CatalogItem] = [:]

    var onOpenDetail: ((Stage26CatalogItem) -> Void)?

    init(store: Stage26CatalogStore, rendering: Rendering) {
        self.store = store
        self.rendering = rendering
        super.init(nibName: nil, bundle: nil)
        LabLog.event("Stage26LegacyListViewController init rendering=\(rendering == .uikitCell ? "uikit" : "swiftui-row")")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = rendering == .uikitCell ? "Legacy UIKit list" : "UIKit list + SwiftUI rows"

        searchBar.placeholder = "Search shared catalog"
        searchBar.text = store.searchQuery
        searchBar.delegate = self

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self

        let stack = UIStackView(arrangedSubviews: [searchBar, tableView])
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Reset",
            style: .plain,
            target: self,
            action: #selector(resetTapped)
        )

        configureDataSource()
        applySnapshot(animated: false)
    }

    @objc
    private func resetTapped() {
        store.resetDemoState()
        searchBar.text = store.searchQuery
        applySnapshot(animated: true)
    }

    private func configureDataSource() {
        dataSource = UITableViewDiffableDataSource<Int, Stage26CatalogItem.ID>(tableView: tableView) { [weak self] (_: UITableView, _: IndexPath, itemID: Stage26CatalogItem.ID) in
            guard let self, let item = self.visibleItemByID[itemID] else {
                return UITableViewCell(style: .default, reuseIdentifier: nil)
            }

            switch self.rendering {
            case .uikitCell:
                let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
                cell.textLabel?.text = item.title
                cell.detailTextLabel?.text = item.subtitle
                cell.accessoryType = self.store.favoriteIDs.contains(item.id) ? .checkmark : .none
                cell.selectionStyle = .default
                return cell

            case .swiftUIRow:
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                let isFavorite = self.store.favoriteIDs.contains(item.id)
                cell.contentConfiguration = UIHostingConfiguration {
                    Stage26CatalogRow(
                        item: item,
                        isFavorite: isFavorite,
                        onToggleFavorite: { [weak self] in
                            self?.store.toggleFavorite(id: item.id)
                            self?.applySnapshot(animated: false)
                        }
                    )
                }
                return cell
            }
        }
    }

    private func applySnapshot(animated: Bool) {
        let visible = store.filteredItems
        visibleItemByID = Dictionary(uniqueKeysWithValues: visible.map { ($0.id, $0) })

        var snapshot = NSDiffableDataSourceSnapshot<Int, Stage26CatalogItem.ID>()
        snapshot.appendSections([0])
        snapshot.appendItems(visible.map(\.id), toSection: 0)

        dataSource.apply(snapshot, animatingDifferences: animated)
        LabLog.event("Stage26LegacyListViewController snapshot rows=\(visible.count)")
    }

    private func toggleFavorite(at indexPath: IndexPath) {
        guard let itemID = dataSource.itemIdentifier(for: indexPath) else { return }
        store.toggleFavorite(id: itemID)
        applySnapshot(animated: false)
    }
}

extension Stage26LegacyListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }

        guard let itemID = dataSource.itemIdentifier(for: indexPath),
              let item = visibleItemByID[itemID]
        else { return }

        onOpenDetail?(item)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let title = "Favorite"
        let action = UIContextualAction(style: .normal, title: title) { [weak self] _, _, completion in
            self?.toggleFavorite(at: indexPath)
            completion(true)
        }
        action.backgroundColor = .systemIndigo

        return UISwipeActionsConfiguration(actions: [action])
    }
}

extension Stage26LegacyListViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        store.searchQuery = searchText
        applySnapshot(animated: true)
    }
}

@MainActor
private final class Stage26UIKitHostRootViewController: UIViewController {
    private let store: Stage26CatalogStore
    private var hostingController: UIHostingController<Stage26HostedSwiftUIFeature>?

    var onOpenDetail: ((Stage26CatalogItem) -> Void)?

    init(store: Stage26CatalogStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Hosted SwiftUI feature"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Reset",
            style: .plain,
            target: self,
            action: #selector(resetTapped)
        )

        let hosted = Stage26HostedSwiftUIFeature(
            store: store,
            onOpenDetail: { [weak self] item in
                self?.onOpenDetail?(item)
            }
        )

        let child = UIHostingController(rootView: hosted)
        child.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(child)
        view.addSubview(child.view)
        NSLayoutConstraint.activate([
            child.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            child.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            child.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        child.didMove(toParent: self)

        hostingController = child
        LabLog.event("Stage26UIKitHostRootViewController embedded UIHostingController")
    }

    @objc
    private func resetTapped() {
        store.resetDemoState()
    }
}

private struct Stage26HostedSwiftUIFeature: View {
    @Bindable var store: Stage26CatalogStore
    let onOpenDetail: (Stage26CatalogItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("UIKit still owns navigation")
                .font(.headline)

            Text("This entire feature UI is SwiftUI, but details are still pushed by UIKit. The shared store is unchanged.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Search", text: $store.searchQuery)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(store.filteredItems) { item in
                        VStack(spacing: 8) {
                            Stage26CatalogRow(
                                item: item,
                                isFavorite: store.favoriteIDs.contains(item.id),
                                onToggleFavorite: {
                                    store.toggleFavorite(id: item.id)
                                }
                            )

                            Button("Open detail via UIKit push") {
                                onOpenDetail(item)
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                        .padding(8)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
    }
}

private struct Stage26PureSwiftUINavigationExercise: View {
    @Bindable var store: Stage26CatalogStore
    @State private var path: [Stage26CatalogItem.ID] = []

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 10) {
                Text("SwiftUI now owns feature navigation")
                    .font(.headline)

                Text("The model/store is the same one used by UIKit phases. Only navigation ownership moved into a SwiftUI path.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Search", text: $store.searchQuery)
                    .textFieldStyle(.roundedBorder)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(store.filteredItems) { item in
                            Button {
                                path.append(item.id)
                            } label: {
                                Stage26CatalogRow(
                                    item: item,
                                    isFavorite: store.favoriteIDs.contains(item.id),
                                    onToggleFavorite: {
                                        store.toggleFavorite(id: item.id)
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .navigationTitle("SwiftUI feature")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Stage26CatalogItem.ID.self) { itemID in
                if let item = store.item(for: itemID) {
                    Stage26SwiftUIDetailView(item: item)
                } else {
                    Text("Item not found")
                }
            }
        }
        .frame(height: 520)
        .stageCard()
    }
}

private struct Stage26CatalogRow: View {
    let item: Stage26CatalogItem
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? .yellow : .secondary)
                    .font(.headline)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
    }
}

@MainActor
@Observable
private final class Stage26CatalogStore {
    var searchQuery: String = ""
    var items: [Stage26CatalogItem]
    var favoriteIDs: Set<Stage26CatalogItem.ID>

    init(
        items: [Stage26CatalogItem] = Stage26CatalogItem.samples,
        favoriteIDs: Set<Stage26CatalogItem.ID> = ["migration-identity"]
    ) {
        self.items = items
        self.favoriteIDs = favoriteIDs
        LabLog.event("Stage26CatalogStore init")
    }

    deinit {
        LabLog.event("Stage26CatalogStore deinit")
    }

    var filteredItems: [Stage26CatalogItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    func toggleFavorite(id: Stage26CatalogItem.ID) {
        if favoriteIDs.contains(id) {
            favoriteIDs.remove(id)
        } else {
            favoriteIDs.insert(id)
        }
        LabLog.event("Stage26CatalogStore toggle favorite \(id)")
    }

    func item(for id: Stage26CatalogItem.ID) -> Stage26CatalogItem? {
        items.first(where: { $0.id == id })
    }

    func resetDemoState() {
        searchQuery = ""
        favoriteIDs = ["migration-identity"]
        LabLog.event("Stage26CatalogStore reset")
    }
}

private struct Stage26CatalogItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String

    nonisolated static let samples: [Stage26CatalogItem] = [
        Stage26CatalogItem(id: "migration-identity", title: "Identity map", subtitle: "Stable IDs survive migration steps."),
        Stage26CatalogItem(id: "migration-coordinator", title: "Legacy coordinator", subtitle: "UIKit still routes pushes while feature UI changes."),
        Stage26CatalogItem(id: "migration-hosting", title: "Hosting boundary", subtitle: "Move a full screen behind UIHostingController."),
        Stage26CatalogItem(id: "migration-navigation", title: "Navigation ownership", subtitle: "Switch to SwiftUI path when feature is ready.")
    ]
}

@MainActor
private final class Stage26ItemDetailViewController: UIViewController {
    private let item: Stage26CatalogItem
    private let source: String

    init(item: Stage26CatalogItem, source: String) {
        self.item = item
        self.source = source
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = item.title

        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .left
        label.text = "Source: \(source)\n\n\(item.subtitle)"
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])
    }
}

private struct Stage26SwiftUIDetailView: View {
    let item: Stage26CatalogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.title)
                .font(.title3.bold())
            Text(item.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
            Text("This detail is now routed by SwiftUI path state.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding()
        .navigationTitle("Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    Stage26UIKitToSwiftUIMigrationView()
}
