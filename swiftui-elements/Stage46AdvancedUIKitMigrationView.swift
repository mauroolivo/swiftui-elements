import Combine
import Observation
import SwiftUI
import UIKit

private enum Stage46MigrationPhase: String, CaseIterable, Identifiable {
    case legacyUIKitScreen = "1) Legacy UIKit screen"
    case swiftUIRowsInUIKit = "2) SwiftUI rows inside UITableView"
    case hostedSwiftUIFeature = "3) SwiftUI feature hosted by UIKit"
    case fullSwiftUIScreen = "4) Whole screen in SwiftUI (UIKit shell)"
    case swiftUINavigationOwnership = "5) Optional: SwiftUI owns navigation"

    var id: Self { self }

    var summary: String {
        switch self {
        case .legacyUIKitScreen:
            "UIKit owns rendering, list state sync, and push navigation."
        case .swiftUIRowsInUIKit:
            "UITableView + diffable data source stay in place, but row rendering moves to SwiftUI."
        case .hostedSwiftUIFeature:
            "Feature UI migrates to SwiftUI while UIKit coordinator still pushes detail."
        case .fullSwiftUIScreen:
            "UIKit only provides the shell. The entire feature surface is SwiftUI."
        case .swiftUINavigationOwnership:
            "Navigation path state moves into SwiftUI NavigationStack."
        }
    }
}

@MainActor
struct Stage46AdvancedUIKitMigrationView: View {
    @State private var phase: Stage46MigrationPhase = .legacyUIKitScreen
    @State private var store = Stage46CatalogStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Stage 46 - Advanced UIKit migration exercise")
                    .font(.title3.bold())

                Text("We keep one shared catalog store while moving boundaries: legacy UIKit table -> SwiftUI rows in UIKit -> hosted SwiftUI feature -> full SwiftUI screen -> optional SwiftUI navigation ownership.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Prediction")
                    .font(.headline)

                Text("Switch phases and toggle favorites/read state. Which state survives every migration step, and exactly when does navigation ownership move?")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Migration phase", selection: $phase) {
                    ForEach(Stage46MigrationPhase.allCases) { current in
                        Text(current.rawValue).tag(current)
                    }
                }
                .pickerStyle(.menu)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Active phase")
                        .font(.subheadline.bold())
                    Text(phase.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Shared state: query=\(store.searchQuery.isEmpty ? "empty" : store.searchQuery), favorites=\(store.favoriteIDs.count), read=\(store.readIDs.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Button("Reset shared store") {
                        store.resetDemoState()
                    }
                    .buttonStyle(.bordered)
                }
                .stageCard()

                switch phase {
                case .legacyUIKitScreen, .swiftUIRowsInUIKit, .hostedSwiftUIFeature, .fullSwiftUIScreen:
                    Stage46UIKitHostSurface(phase: phase, store: store)
                        .frame(height: 560)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.quaternary)
                        }
                        .id(phase)

                case .swiftUINavigationOwnership:
                    Stage46PureSwiftUINavigationSurface(store: store)
                }

                Text("Takeaway: migration can preserve model and service layers while only changing UI ownership boundaries.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

private struct Stage46UIKitHostSurface: UIViewControllerRepresentable {
    let phase: Stage46MigrationPhase
    let store: Stage46CatalogStore

    func makeUIViewController(context: Context) -> Stage46MigrationNavigationController {
        Stage46MigrationNavigationController(phase: phase, store: store)
    }

    func updateUIViewController(_ uiViewController: Stage46MigrationNavigationController, context: Context) {
        uiViewController.applyPhase(phase)
    }
}

@MainActor
private final class Stage46MigrationNavigationController: UINavigationController {
    private let coordinator: Stage46MigrationCoordinator
    private var currentPhase: Stage46MigrationPhase

    init(phase: Stage46MigrationPhase, store: Stage46CatalogStore) {
        self.coordinator = Stage46MigrationCoordinator(store: store)
        self.currentPhase = phase

        let root = coordinator.makeRoot(for: phase)
        super.init(rootViewController: root)
        coordinator.attach(navigationController: self)
        navigationBar.prefersLargeTitles = false
        LabLog.event("Stage46MigrationNavigationController init phase=\(phase.rawValue)")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyPhase(_ phase: Stage46MigrationPhase) {
        guard phase != currentPhase else { return }
        currentPhase = phase

        let root = coordinator.makeRoot(for: phase)
        setViewControllers([root], animated: false)
        LabLog.event("Stage46MigrationNavigationController applied phase=\(phase.rawValue)")
    }
}

@MainActor
private protocol Stage46LegacyListViewControllerDelegate: AnyObject {
    func legacyListViewController(_ controller: Stage46LegacyListViewController, didSelect item: Stage46CatalogItem)
}

@MainActor
private final class Stage46MigrationCoordinator: NSObject {
    private weak var navigationController: UINavigationController?
    private let store: Stage46CatalogStore

    init(store: Stage46CatalogStore) {
        self.store = store
        LabLog.event("Stage46MigrationCoordinator init")
    }

    func attach(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func makeRoot(for phase: Stage46MigrationPhase) -> UIViewController {
        switch phase {
        case .legacyUIKitScreen:
            return makeLegacyList(rendering: .legacyUIKitCell)

        case .swiftUIRowsInUIKit:
            return makeLegacyList(rendering: .swiftUIRow)

        case .hostedSwiftUIFeature:
            let controller = Stage46UIKitHostedFeatureViewController(store: store)
            controller.onOpenDetail = { [weak self] item in
                self?.pushDetail(item: item, source: "Hosted SwiftUI feature")
            }
            return controller

        case .fullSwiftUIScreen:
            return Stage46FullSwiftUIScreenController(store: store)

        case .swiftUINavigationOwnership:
            return UIViewController()
        }
    }

    private func makeLegacyList(rendering: Stage46LegacyListViewController.Rendering) -> UIViewController {
        let controller = Stage46LegacyListViewController(store: store, rendering: rendering)
        controller.delegate = self
        return controller
    }

    private func pushDetail(item: Stage46CatalogItem, source: String) {
        let detail = Stage46ItemDetailViewController(item: item, source: source)
        navigationController?.pushViewController(detail, animated: true)
    }
}

extension Stage46MigrationCoordinator: Stage46LegacyListViewControllerDelegate {
    func legacyListViewController(_ controller: Stage46LegacyListViewController, didSelect item: Stage46CatalogItem) {
        let source = controller.rendering == .legacyUIKitCell ? "Legacy UIKit list" : "UIKit list with SwiftUI row"
        pushDetail(item: item, source: source)
    }
}

@MainActor
private final class Stage46LegacyListViewController: UIViewController {
    enum Rendering {
        case legacyUIKitCell
        case swiftUIRow
    }

    private let store: Stage46CatalogStore
    let rendering: Rendering

    private let searchBar = UISearchBar(frame: .zero)
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var dataSource: UITableViewDiffableDataSource<Int, Stage46CatalogItem.ID>!
    private var visibleItemByID: [Stage46CatalogItem.ID: Stage46CatalogItem] = [:]
    private var eventCancellable: AnyCancellable?

    weak var delegate: Stage46LegacyListViewControllerDelegate?

    init(store: Stage46CatalogStore, rendering: Rendering) {
        self.store = store
        self.rendering = rendering
        super.init(nibName: nil, bundle: nil)
        LabLog.event("Stage46LegacyListViewController init rendering=\(rendering == .legacyUIKitCell ? "uikit" : "swiftui-row")")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = rendering == .legacyUIKitCell ? "Legacy UIKit table" : "UIKit table + SwiftUI rows"

        searchBar.placeholder = "Search catalog"
        searchBar.text = store.searchQuery
        searchBar.delegate = self

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self

        let stack = UIStackView(arrangedSubviews: [searchBar, tableView])
        stack.axis = .vertical
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
        bindLegacyObservers()
        applySnapshot(animated: false)
    }

    deinit {
        eventCancellable?.cancel()
    }

    @objc
    private func resetTapped() {
        store.resetDemoState()
        searchBar.text = store.searchQuery
    }

    private func bindLegacyObservers() {
        eventCancellable = store.events
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.searchBar.text = self?.store.searchQuery
                self?.applySnapshot(animated: true)
            }
    }

    private func configureDataSource() {
        dataSource = UITableViewDiffableDataSource<Int, Stage46CatalogItem.ID>(tableView: tableView) { [weak self] (_: UITableView, _: IndexPath, itemID: Stage46CatalogItem.ID) in
            guard let self, let item = self.visibleItemByID[itemID] else {
                return UITableViewCell(style: .default, reuseIdentifier: nil)
            }

            switch self.rendering {
            case .legacyUIKitCell:
                let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
                cell.textLabel?.text = item.title
                cell.detailTextLabel?.text = item.subtitle
                cell.accessoryType = self.store.favoriteIDs.contains(item.id) ? .checkmark : .none
                return cell

            case .swiftUIRow:
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                let isFavorite = self.store.favoriteIDs.contains(item.id)
                let isRead = self.store.readIDs.contains(item.id)

                cell.contentConfiguration = UIHostingConfiguration {
                    Stage46SwiftUIRow(
                        item: item,
                        isFavorite: isFavorite,
                        isRead: isRead,
                        onToggleFavorite: { [weak self] in
                            self?.store.toggleFavorite(id: item.id)
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

        var snapshot = NSDiffableDataSourceSnapshot<Int, Stage46CatalogItem.ID>()
        snapshot.appendSections([0])
        snapshot.appendItems(visible.map(\.id), toSection: 0)
        dataSource.apply(snapshot, animatingDifferences: animated)

        LabLog.event("Stage46LegacyListViewController snapshot rows=\(visible.count)")
    }

    private func toggleFavorite(at indexPath: IndexPath) {
        guard let itemID = dataSource.itemIdentifier(for: indexPath) else { return }
        store.toggleFavorite(id: itemID)
    }

    private func markRead(at indexPath: IndexPath) {
        guard let itemID = dataSource.itemIdentifier(for: indexPath) else { return }
        store.markRead(id: itemID)
    }
}

extension Stage46LegacyListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }

        guard let itemID = dataSource.itemIdentifier(for: indexPath),
              let item = visibleItemByID[itemID]
        else { return }

        store.markRead(id: item.id)
        delegate?.legacyListViewController(self, didSelect: item)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let favoriteAction = UIContextualAction(style: .normal, title: "Favorite") { [weak self] _, _, completion in
            self?.toggleFavorite(at: indexPath)
            completion(true)
        }
        favoriteAction.backgroundColor = .systemIndigo

        let readAction = UIContextualAction(style: .normal, title: "Read") { [weak self] _, _, completion in
            self?.markRead(at: indexPath)
            completion(true)
        }
        readAction.backgroundColor = .systemGreen

        return UISwipeActionsConfiguration(actions: [favoriteAction, readAction])
    }
}

extension Stage46LegacyListViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        store.searchQuery = searchText
    }
}

@MainActor
private final class Stage46UIKitHostedFeatureViewController: UIViewController {
    private let store: Stage46CatalogStore

    var onOpenDetail: ((Stage46CatalogItem) -> Void)?

    init(store: Stage46CatalogStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Hosted SwiftUI feature"
        view.backgroundColor = .systemBackground

        let hosted = Stage46HostedSwiftUIFeature(
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
    }
}

private struct Stage46HostedSwiftUIFeature: View {
    @Bindable var store: Stage46CatalogStore
    let onOpenDetail: (Stage46CatalogItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("UIKit still owns navigation")
                .font(.headline)

            Text("This feature is fully SwiftUI for rendering, but detail routing is still delegated to a UIKit coordinator.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Search", text: $store.searchQuery)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(store.filteredItems) { item in
                        VStack(spacing: 8) {
                            Stage46SwiftUIRow(
                                item: item,
                                isFavorite: store.favoriteIDs.contains(item.id),
                                isRead: store.readIDs.contains(item.id),
                                onToggleFavorite: {
                                    store.toggleFavorite(id: item.id)
                                }
                            )

                            Button("Open detail via UIKit push") {
                                store.markRead(id: item.id)
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

@MainActor
private final class Stage46FullSwiftUIScreenController: UIViewController {
    private let store: Stage46CatalogStore

    init(store: Stage46CatalogStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "SwiftUI screen in UIKit shell"
        view.backgroundColor = .systemBackground

        let child = UIHostingController(rootView: Stage46StandaloneSwiftUIScreen(store: store))
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
    }
}

private struct Stage46StandaloneSwiftUIScreen: View {
    @Bindable var store: Stage46CatalogStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Whole screen is SwiftUI")
                .font(.headline)

            Text("UIKit still owns this shell UIViewController, but feature state and view hierarchy are all SwiftUI.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Search", text: $store.searchQuery)
                .textFieldStyle(.roundedBorder)

            List {
                ForEach(store.filteredItems) { item in
                    Stage46SwiftUIRow(
                        item: item,
                        isFavorite: store.favoriteIDs.contains(item.id),
                        isRead: store.readIDs.contains(item.id),
                        onToggleFavorite: {
                            store.toggleFavorite(id: item.id)
                        }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        store.markRead(id: item.id)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                }
            }
            .listStyle(.plain)
        }
        .padding()
    }
}

private struct Stage46PureSwiftUINavigationSurface: View {
    @Bindable var store: Stage46CatalogStore
    @State private var path: [Stage46CatalogItem.ID] = []

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 10) {
                Text("SwiftUI now owns navigation state")
                    .font(.headline)

                Text("The shared store is unchanged. Only navigation moved from coordinator callbacks to typed path state.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Search", text: $store.searchQuery)
                    .textFieldStyle(.roundedBorder)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(store.filteredItems) { item in
                            Button {
                                store.markRead(id: item.id)
                                path.append(item.id)
                            } label: {
                                Stage46SwiftUIRow(
                                    item: item,
                                    isFavorite: store.favoriteIDs.contains(item.id),
                                    isRead: store.readIDs.contains(item.id),
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
            .navigationTitle("SwiftUI-owned flow")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Stage46CatalogItem.ID.self) { itemID in
                if let item = store.item(for: itemID) {
                    Stage46SwiftUIDetailView(item: item)
                } else {
                    Text("Item not found")
                }
            }
        }
        .frame(height: 560)
        .stageCard()
    }
}

private struct Stage46SwiftUIRow: View {
    let item: Stage46CatalogItem
    let isFavorite: Bool
    let isRead: Bool
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    if isRead {
                        Text("read")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.15), in: Capsule())
                    }
                }

                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
    }
}

@MainActor
@Observable
private final class Stage46CatalogStore {
    enum Event {
        case didChange(String)
    }

    var searchQuery: String = "" {
        didSet { events.send(.didChange("searchQuery")) }
    }
    var items: [Stage46CatalogItem]
    var favoriteIDs: Set<Stage46CatalogItem.ID>
    var readIDs: Set<Stage46CatalogItem.ID>

    nonisolated let events = PassthroughSubject<Event, Never>()

    init(
        items: [Stage46CatalogItem] = Stage46CatalogItem.samples,
        favoriteIDs: Set<Stage46CatalogItem.ID> = ["migration-bridge"],
        readIDs: Set<Stage46CatalogItem.ID> = []
    ) {
        self.items = items
        self.favoriteIDs = favoriteIDs
        self.readIDs = readIDs
        LabLog.event("Stage46CatalogStore init")
    }

    deinit {
        LabLog.event("Stage46CatalogStore deinit")
    }

    var filteredItems: [Stage46CatalogItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    func toggleFavorite(id: Stage46CatalogItem.ID) {
        if favoriteIDs.contains(id) {
            favoriteIDs.remove(id)
        } else {
            favoriteIDs.insert(id)
        }
        events.send(.didChange("favoriteIDs"))
    }

    func markRead(id: Stage46CatalogItem.ID) {
        readIDs.insert(id)
        events.send(.didChange("readIDs"))
    }

    func item(for id: Stage46CatalogItem.ID) -> Stage46CatalogItem? {
        items.first(where: { $0.id == id })
    }

    func resetDemoState() {
        searchQuery = ""
        favoriteIDs = ["migration-bridge"]
        readIDs = []
        events.send(.didChange("reset"))
    }
}

private struct Stage46CatalogItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String

    nonisolated static let samples: [Stage46CatalogItem] = [
        Stage46CatalogItem(id: "migration-bridge", title: "Bridge legacy delegates", subtitle: "Coordinator and delegates can coexist with SwiftUI state."),
        Stage46CatalogItem(id: "migration-row", title: "Migrate row first", subtitle: "Use UIHostingConfiguration while table and diffable stay untouched."),
        Stage46CatalogItem(id: "migration-host", title: "Host feature", subtitle: "Move screen rendering to SwiftUI via UIHostingController."),
        Stage46CatalogItem(id: "migration-nav", title: "Own navigation", subtitle: "Adopt NavigationStack when feature is ready to own path state.")
    ]
}

@MainActor
private final class Stage46ItemDetailViewController: UIViewController {
    private let item: Stage46CatalogItem
    private let source: String

    init(item: Stage46CatalogItem, source: String) {
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

private struct Stage46SwiftUIDetailView: View {
    let item: Stage46CatalogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.title)
                .font(.title3.bold())
            Text(item.subtitle)
                .foregroundStyle(.secondary)
            Text("Navigation is now SwiftUI path state.")
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
    Stage46AdvancedUIKitMigrationView()
}
