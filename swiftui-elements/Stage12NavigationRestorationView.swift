import SwiftUI

// MARK: - Codable Routes

enum Restorable_CatalogRoute: Codable, Hashable {
    case item(String) // itemID
    
    enum CodingKeys: String, CodingKey {
        case type
        case itemID
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .item(let id):
            try container.encode("item", forKey: .type)
            try container.encode(id, forKey: .itemID)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "item":
            let id = try container.decode(String.self, forKey: .itemID)
            self = .item(id)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown route type: \(type)"
            )
        }
    }
}

// MARK: - Navigation State Persistence

struct RestorationSnapshot: Codable {
    let navigationPath: [Restorable_CatalogRoute]
    let selectedTab: String
    let searchQuery: String
    let timestamp: TimeInterval
}

@MainActor
final class NavigationPersistence {
    private static let navigationKey = "stage12.navigationPath"
    private static let tabKey = "stage12.selectedTab"
    private static let searchKey = "stage12.searchQuery"
    
    // Save navigation state
    static func saveNavigationState(
        path: [Restorable_CatalogRoute],
        selectedTab: AppTab,
        searchQuery: String
    ) {
        let snapshot = RestorationSnapshot(
            navigationPath: path,
            selectedTab: selectedTab.rawValue,
            searchQuery: searchQuery,
            timestamp: Date().timeIntervalSince1970
        )
        
        do {
            let data = try JSONEncoder().encode(snapshot)
            UserDefaults.standard.set(data, forKey: navigationKey)
            LabLog.event("Stage12: saved navigation snapshot at \(Date())")
        } catch {
            LabLog.event("Stage12: failed to encode navigation state: \(error)")
        }
    }
    
    // Restore navigation state
    static func restoreNavigationState() -> RestorationSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: navigationKey) else {
            LabLog.event("Stage12: no saved navigation state found")
            return nil
        }
        
        do {
            let snapshot = try JSONDecoder().decode(RestorationSnapshot.self, from: data)
            LabLog.event("Stage12: restored navigation snapshot from \(Date(timeIntervalSince1970: snapshot.timestamp))")
            return snapshot
        } catch {
            LabLog.event("Stage12: failed to decode navigation state: \(error)")
            return nil
        }
    }
    
    // Clear all navigation state (e.g., on logout)
    static func clearNavigationState() {
        UserDefaults.standard.removeObject(forKey: navigationKey)
        LabLog.event("Stage12: cleared all navigation state")
    }
}

// MARK: - Validation Helper

struct NavigationStateValidator {
    private let availableItemIDs: Set<String>
    
    init(availableItemIDs: [CatalogItem.ID]) {
        self.availableItemIDs = Set(availableItemIDs)
    }
    
    func validate(_ route: Restorable_CatalogRoute) -> Bool {
        switch route {
        case .item(let id):
            return availableItemIDs.contains(id)
        }
    }
    
    func validatePath(_ path: [Restorable_CatalogRoute]) -> [Restorable_CatalogRoute] {
        path.filter { validate($0) }
    }
}

// MARK: - Stage 12 Navigation Restoration View

@MainActor
struct Stage12NavigationRestorationView: View {
    @State private var isPersistenceEnabled = true
    @State private var navigationPath: [Restorable_CatalogRoute] = []
    @State private var selectedTab: AppTab = .catalog
    @State private var searchQuery = ""
    @State private var restoredSnapshot: RestorationSnapshot?
    @State private var validationResult = ""
    
    private let availableItems = CatalogItem.samples
    
    init() {
        LabLog.event("Stage12NavigationRestorationView init")
    }
    
    var body: some View {
        let _ = LabLog.event("Stage12NavigationRestorationView body")
        
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Stage 12 — Navigation restoration")
                    .font(.title2.bold())
                
                NavigationRestorationConceptPanel()
                NavigationPersistenceModePanel(isEnabled: $isPersistenceEnabled)
                NavigationStateSimulationPanel(
                    onSave: saveCurrentState,
                    onRestore: attemptRestore,
                    onClear: clearSavedState
                )
                NavigationPathEditorPanel(
                    path: $navigationPath,
                    selectedTab: $selectedTab,
                    searchQuery: $searchQuery,
                    availableItems: availableItems
                )
                RestoredSnapshotPanel(
                    snapshot: restoredSnapshot,
                    validationResult: validationResult
                )
                CurrentNavigationStatePanel(
                    selectedTab: selectedTab,
                    pathCount: navigationPath.count,
                    searchQuery: searchQuery,
                    isPersistenceEnabled: isPersistenceEnabled
                )
            }
            .padding()
        }
        .onAppear {
            if isPersistenceEnabled {
                attemptRestore()
            }
        }
    }
    
    private func saveCurrentState() {
        guard isPersistenceEnabled else {
            LabLog.event("Stage12: persistence is disabled, not saving")
            return
        }
        NavigationPersistence.saveNavigationState(
            path: navigationPath,
            selectedTab: selectedTab,
            searchQuery: searchQuery
        )
    }
    
    private func attemptRestore() {
        guard isPersistenceEnabled else {
            LabLog.event("Stage12: persistence is disabled, not restoring")
            validationResult = "Persistence disabled"
            return
        }
        
        guard let snapshot = NavigationPersistence.restoreNavigationState() else {
            validationResult = "No saved state found"
            return
        }
        
        restoredSnapshot = snapshot
        
        // Validate routes against available items
        let validator = NavigationStateValidator(availableItemIDs: availableItems.map(\.id))
        let validatedPath = validator.validatePath(snapshot.navigationPath)
        
        validationResult = """
        Restored \(snapshot.navigationPath.count) routes
        Valid after filtering: \(validatedPath.count)
        Timestamp: \(formatTime(snapshot.timestamp))
        """
        
        navigationPath = validatedPath
        selectedTab = AppTab(rawValue: snapshot.selectedTab) ?? .catalog
        searchQuery = snapshot.searchQuery
        
        LabLog.event("Stage12: restored and validated \(validatedPath.count) valid routes (discarded \(snapshot.navigationPath.count - validatedPath.count) invalid)")
    }
    
    private func clearSavedState() {
        NavigationPersistence.clearNavigationState()
        restoredSnapshot = nil
        validationResult = "Cleared"
    }
    
    private func formatTime(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Concept Panel

private struct NavigationRestorationConceptPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Concept")
                .font(.headline)
            
            Text("Navigation restoration saves navigation state so the app can resume exactly where it left off after termination.")
            
            VStack(alignment: .leading, spacing: 4) {
                BulletPoint("User launches app → see Catalog detail at previous position")
                BulletPoint("But not blindly: validate IDs still exist (deleted items, app version mismatch)")
                BulletPoint("Logout should clear all navigation (no cross-session leaks)")
                BulletPoint("Not everything needs restoration: ephemeral UI state usually doesn't")
            }
            .padding(.leading, 12)
            
            Text("The key: restoration should be robust, not magical.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

// MARK: - Persistence Mode Panel

private struct NavigationPersistenceModePanel: View {
    @Binding var isEnabled: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Persistence configuration")
                .font(.headline)
            
            Toggle("Enable navigation state persistence", isOn: $isEnabled)
            
            Text(isEnabled
                ? "Navigation state will be saved and restored"
                : "Navigation state will NOT be persisted (fresh launch each time)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

// MARK: - Simulation Panel

private struct NavigationStateSimulationPanel: View {
    let onSave: () -> Void
    let onRestore: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manual save/restore simulation")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Button(action: onSave) {
                    HStack {
                        Image(systemName: "arrow.down.doc")
                        Text("Save current state to UserDefaults")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Button(action: onRestore) {
                    HStack {
                        Image(systemName: "arrow.up.doc")
                        Text("Restore saved state")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Button(action: onClear) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear saved state")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            Text("In a real app, save happens on app background (scenePhase). Restore happens on app launch automatically if persistence is enabled.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

// MARK: - Path Editor Panel

private struct NavigationPathEditorPanel: View {
    @Binding var path: [Restorable_CatalogRoute]
    @Binding var selectedTab: AppTab
    @Binding var searchQuery: String
    let availableItems: [CatalogItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit navigation state")
                .font(.headline)
            
            Picker("Selected tab", selection: $selectedTab) {
                ForEach(AppTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            
            TextField("Search query", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Navigation path")
                    .font(.caption.bold())
                
                ForEach(Array(path.enumerated()), id: \.offset) { index, route in
                    HStack {
                        Text("\(index)")
                            .foregroundStyle(.secondary)
                        Text(routeDescription(route))
                            .font(.caption.monospaced())
                        Spacer()
                        Button(action: { path.remove(at: index) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                if path.isEmpty {
                    Text("(empty path)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Menu("Add route...") {
                    ForEach(availableItems) { item in
                        Button("Item: \(item.title)") {
                            path.append(.item(item.id))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .stageCard()
    }
    
    private func routeDescription(_ route: Restorable_CatalogRoute) -> String {
        switch route {
        case .item(let id):
            return "item(\"\(id)\")"
        }
    }
}

// MARK: - Restored Snapshot Panel

private struct RestoredSnapshotPanel: View {
    let snapshot: RestorationSnapshot?
    let validationResult: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Restoration result")
                .font(.headline)
            
            if validationResult.isEmpty {
                Text("No restoration attempted yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(validationResult)
                    .font(.caption.monospaced())
                    .lineLimit(nil)
            }
            
            if let snapshot = snapshot {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Snapshot details:").font(.caption.bold())
                    Text("Tab: \(snapshot.selectedTab)")
                        .font(.caption)
                    Text("Routes: \(snapshot.navigationPath.count)")
                        .font(.caption)
                    Text("Search: \"\(snapshot.searchQuery.isEmpty ? "(empty)" : snapshot.searchQuery)\"")
                        .font(.caption)
                }
                .padding(.top, 8)
            }
        }
        .stageCard()
    }
}

// MARK: - Current State Panel

private struct CurrentNavigationStatePanel: View {
    let selectedTab: AppTab
    let pathCount: Int
    let searchQuery: String
    let isPersistenceEnabled: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current state")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                StateRow(label: "Selected tab", value: selectedTab.rawValue)
                StateRow(label: "Path depth", value: "\(pathCount)")
                StateRow(label: "Search query", value: searchQuery.isEmpty ? "(empty)" : searchQuery)
                StateRow(label: "Persistence", value: isPersistenceEnabled ? "enabled" : "disabled")
            }
            
            Text("Navigation state is separate from domain state (items, favorites). Restoration should only revive navigation, not reload the entire app.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

// MARK: - Helpers

private struct BulletPoint: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
    }
}

private struct StateRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption.bold())
            Spacer()
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Stage 12 navigation restoration") {
    Stage12NavigationRestorationView()
}
