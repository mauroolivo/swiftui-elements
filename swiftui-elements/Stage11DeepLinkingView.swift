import SwiftUI

// MARK: - Deep Link Model

enum DeepLink: Hashable, CustomStringConvertible {
    case home
    case catalogItem(CatalogItem.ID)
    case search(query: String)
    case favorites
    case settings
    case invalid(String)
    
    var description: String {
        switch self {
        case .home:
            return "myapp://home"
        case .catalogItem(let id):
            return "myapp://item/\(id)"
        case .search(let query):
            return "myapp://search?q=\(query)"
        case .favorites:
            return "myapp://favorites"
        case .settings:
            return "myapp://settings"
        case .invalid(let url):
            return "invalid://\(url)"
        }
    }
}

// MARK: - Deep Link Parser

struct DeepLinkParser {
    static func parse(url: URL) -> DeepLink {
        LabLog.event("DeepLinkParser parsing URL: \(url)")
        
        guard let scheme = url.scheme, scheme == "myapp" else {
            return .invalid(url.absoluteString)
        }
        
        guard let host = url.host else {
            return .invalid(url.absoluteString)
        }
        
        switch host {
        case "home":
            return .home
            
        case "item":
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            guard let itemID = pathComponents.first else {
                return .invalid(url.absoluteString)
            }
            return .catalogItem(itemID)
            
        case "search":
            if let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "q" })?
                .value {
                return .search(query: query)
            }
            return .invalid(url.absoluteString)
            
        case "favorites":
            return .favorites
            
        case "settings":
            return .settings
            
        default:
            return .invalid(url.absoluteString)
        }
    }
}

// MARK: - Stage 11 Deep Linking View

@MainActor
struct Stage11DeepLinkingView: View {
    @State private var lastParsedDeepLink: DeepLink?
    @State private var isReplaceMode = true
    @State private var navigationHistory: [DeepLink] = []
    @State private var selectedTab: AppTab = .home
    @State private var catalogPath: [CatalogRoute] = []
    @State private var searchQuery = ""
    
    init() {
        LabLog.event("Stage11DeepLinkingView init")
    }
    
    var body: some View {
        let _ = LabLog.event("Stage11DeepLinkingView body")
        
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Stage 11 — Deep linking")
                    .font(.title2.bold())
                
                DeepLinkConceptPanel()
                DeepLinkParsingPanel(onParse: handleDeepLink)
                DeepLinkNavigationModePanel(isReplaceMode: $isReplaceMode)
                DeepLinkHistoryPanel(history: navigationHistory)
                DeepLinkSimulationPanel(onOpenURL: handleDeepLink)
                CurrentNavigationStatePanel(
                    selectedTab: selectedTab,
                    catalogPath: catalogPath,
                    searchQuery: searchQuery
                )
            }
            .padding()
        }
        .onOpenURL { url in
            LabLog.event("Stage11DeepLinkingView received URL: \(url)")
            handleDeepLink(DeepLinkParser.parse(url: url))
        }
    }
    
    private func handleDeepLink(_ deepLink: DeepLink) {
        LabLog.event("Stage11: handling deep link \(deepLink)")
        
        lastParsedDeepLink = deepLink
        
        if isReplaceMode {
            navigationHistory.removeAll()
        }
        navigationHistory.append(deepLink)
        
        switch deepLink {
        case .home:
            selectedTab = .home
            catalogPath.removeAll()
            searchQuery = ""
            
        case .catalogItem(let id):
            selectedTab = .catalog
            if isReplaceMode {
                catalogPath = [.item(id)]
            } else {
                catalogPath.append(.item(id))
            }
            
        case .search(let query):
            selectedTab = .search
            searchQuery = query
            
        case .favorites:
            selectedTab = .favorites
            
        case .settings:
            // Presentation would happen here in a real app
            LabLog.event("Stage11: settings sheet would be presented")
            
        case .invalid(let url):
            LabLog.event("Stage11: invalid deep link \(url)")
        }
    }
}

// MARK: - Concept Panel

private struct DeepLinkConceptPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Concept")
                .font(.headline)
            
            Text("Deep links are URLs that route the app to a specific screen or state. They enable:")
            
            VStack(alignment: .leading, spacing: 4) {
                BulletPoint("Launching from terminated state (cold start)")
                BulletPoint("Handling notifications/system events")
                BulletPoint("Cross-feature navigation")
                BulletPoint("Replacing or appending to navigation paths")
                BulletPoint("Recovering gracefully from invalid links")
            }
            .padding(.leading, 12)
            
            Text("The key distinction: URL parsing should be separate from navigation state updates.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

// MARK: - Parsing Panel

private struct DeepLinkParsingPanel: View {
    let onParse: (DeepLink) -> Void
    @State private var urlInput = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parse a deep link URL")
                .font(.headline)
            
            TextField("Enter a myapp:// URL", text: $urlInput)
                .textFieldStyle(.roundedBorder)
            
            HStack(spacing: 8) {
                Button("Parse URL") {
                    if let url = URL(string: urlInput) {
                        let deepLink = DeepLinkParser.parse(url: url)
                        onParse(deepLink)
                        LabLog.event("Parsed: \(deepLink)")
                    }
                }
                
                Spacer()
                
                Button("Clear") {
                    urlInput = ""
                }
                .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Example URLs:").font(.caption.bold())
                ExampleLink("myapp://home")
                ExampleLink("myapp://item/identity")
                ExampleLink("myapp://search?q=state")
                ExampleLink("myapp://favorites")
                ExampleLink("myapp://settings")
            }
            .padding(.top, 8)
        }
        .stageCard()
    }
}

// MARK: - Navigation Mode Panel

private struct DeepLinkNavigationModePanel: View {
    @Binding var isReplaceMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Navigation mode")
                .font(.headline)
            
            Picker("Mode", selection: $isReplaceMode) {
                Text("Replace path").tag(true)
                Text("Append to path").tag(false)
            }
            .pickerStyle(.segmented)
            
            Text(isReplaceMode
                ? "Replace: each deep link clears history and starts fresh"
                : "Append: deep links build on existing navigation stack")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

// MARK: - History Panel

private struct DeepLinkHistoryPanel: View {
    let history: [DeepLink]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Navigation history")
                .font(.headline)
            
            if history.isEmpty {
                Text("No deep links parsed yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(history.enumerated()), id: \.offset) { index, deepLink in
                        HStack(spacing: 8) {
                            Text("\(index + 1).")
                                .foregroundStyle(.secondary)
                            Text(deepLink.description)
                                .font(.caption.monospaced())
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .stageCard()
    }
}

// MARK: - Simulation Panel

private struct DeepLinkSimulationPanel: View {
    let onOpenURL: (DeepLink) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Simulate deep link handling")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Button("Open: myapp://home") {
                    onOpenURL(.home)
                }
                
                Button("Open: myapp://item/identity") {
                    onOpenURL(.catalogItem("identity"))
                }
                
                Button("Open: myapp://search?q=SwiftUI") {
                    onOpenURL(.search(query: "SwiftUI"))
                }
                
                Button("Open: myapp://favorites") {
                    onOpenURL(.favorites)
                }
                
                Button("Open: invalid link") {
                    onOpenURL(.invalid("myapp://unknown"))
                }
            }
            
            Text("In a real app, these would be triggered by .onOpenURL(perform:) when the system opens the app with a URL (notification tap, link click, etc.)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

// MARK: - Current State Panel

private struct CurrentNavigationStatePanel: View {
    let selectedTab: AppTab
    let catalogPath: [CatalogRoute]
    let searchQuery: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current navigation state")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                StateRow(label: "Selected tab", value: selectedTab.rawValue)
                StateRow(label: "Catalog path depth", value: "\(catalogPath.count)")
                StateRow(label: "Search query", value: searchQuery.isEmpty ? "(empty)" : searchQuery)
            }
            
            Text("Deep links should update this state, not internal UI flags. The key distinction from Stage 9: here, deep link handling updates navigation state explicitly.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

// MARK: - Helpers

private struct ExampleLink: View {
    let url: String
    
    init(_ url: String) {
        self.url = url
    }
    
    var body: some View {
        Text(url)
            .font(.caption.monospaced())
            .foregroundStyle(.blue)
    }
}

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

#Preview("Stage 11 deep linking") {
    Stage11DeepLinkingView()
}
