import Observation
import SwiftUI

@MainActor
struct Stage37TestingModelDrivenSwiftUIView: View {
    @State private var lab = Stage37ModelTestingLab()
    @State private var deepLinkInput = "switui-elements://item/42"

    var body: some View {
        NavigationStack {
            List {
                Section("Stage 37 - Testing model-driven SwiftUI") {
                    Text("Concept")
                        .font(.headline)
                    Text("Most SwiftUI behavior worth testing lives in state models, routers, and parsers. If transitions are explicit and deterministic, you can validate behavior without rendering a view hierarchy.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Problem")
                        .font(.headline)
                    Text("UI tests are important but slower and broader. If we only test through UI, logic regressions like bad deep-link parsing or logout-reset bugs are harder to isolate.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Prediction")
                        .font(.headline)
                    Text("Before running: if a user logs out, which pieces of state must reset? Should invalid deep links mutate navigation state at all?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Implementation") {
                    Text("The checks below execute pure model logic. The view only displays results; it does not participate in the tested state transitions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Run model checks") {
                        lab.runAll()
                    }

                    if lab.results.isEmpty {
                        Text("No checks run yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Run #\(lab.runCount) - \(lab.passedCount)/\(lab.results.count) passed")
                            .font(.subheadline.bold())

                        ForEach(lab.results) { result in
                            VStack(alignment: .leading, spacing: 4) {
                                Label(result.name, systemImage: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(result.passed ? .green : .red)

                                if let message = result.message {
                                    Text(message)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section("Manual parser probe") {
                    TextField("Deep link", text: $deepLinkInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    let parseSummary = lab.parsePreview(urlString: deepLinkInput)
                    Text(parseSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Run") {
                    Text("1) Tap 'Run model checks' and verify all checks pass.")
                    Text("2) Edit the deep-link text field with valid and invalid links.")
                    Text("3) Intentionally break one model rule (for example, remove logout reset) and rerun checks to see deterministic failure output.")
                }

                Section("Explanation") {
                    Text("These checks assert invariants at the model boundary: URL -> typed deep link, typed deep link -> router state, logout -> navigation reset policy. This keeps tests focused on ownership and source-of-truth transitions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("When tests are written around plain models, SwiftUI view recomputation details become implementation noise rather than test setup complexity.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Refactor") {
                    Text("Next, move these checks into a dedicated Swift Testing target (`@Test`) so they run in CI and fail builds automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Takeaway") {
                    Text("- Test state transitions and parsing logic directly; keep views thin.")
                    Text("- Express navigation/logout policies as deterministic model behavior.")
                    Text("- Add focused UI tests only for critical end-to-end integration paths.")
                }
            }
            .navigationTitle("Model Testing")
        }
        .onAppear {
            LabLog.event("Stage37TestingModelDrivenSwiftUIView onAppear")
        }
    }
}

@MainActor
@Observable
private final class Stage37ModelTestingLab {
    var runCount = 0
    var results: [Stage37CheckResult] = []

    var passedCount: Int {
        results.filter(\.passed).count
    }

    func runAll() {
        runCount += 1
        let checks = Stage37ModelCheckSuite.makeChecks()
        results = checks.map { check in
            do {
                try check.run()
                return Stage37CheckResult(name: check.name, passed: true, message: nil)
            } catch {
                return Stage37CheckResult(name: check.name, passed: false, message: String(describing: error))
            }
        }
        LabLog.event("Stage37 checks run #\(runCount): \(passedCount)/\(results.count) passed")
    }

    func parsePreview(urlString: String) -> String {
        guard let link = Stage37DeepLinkParser().parse(urlString: urlString) else {
            return "Invalid link"
        }

        switch link {
        case .item(let id):
            return "Parsed: item(\(id))"
        case .search(let query):
            return "Parsed: search(\(query))"
        }
    }
}

private struct Stage37CheckResult: Identifiable {
    let id = UUID()
    let name: String
    let passed: Bool
    let message: String?
}

private struct Stage37ModelCheckSuite {
    static func makeChecks() -> [Stage37ModelCheck] {
        [
            Stage37ModelCheck(name: "DeepLink parser reads item route") {
                let parser = Stage37DeepLinkParser()
                let parsed = parser.parse(urlString: "switui-elements://item/42")
                try Stage37Assert.equal(parsed, .item("42"), "Expected item deep link with id=42")
            },
            Stage37ModelCheck(name: "DeepLink parser decodes search query") {
                let parser = Stage37DeepLinkParser()
                let parsed = parser.parse(urlString: "switui-elements://search?q=swift%20ui")
                try Stage37Assert.equal(parsed, .search("swift ui"), "Expected decoded query string")
            },
            Stage37ModelCheck(name: "Invalid links are rejected") {
                let parser = Stage37DeepLinkParser()
                let parsed = parser.parse(urlString: "https://example.com/item/42")
                try Stage37Assert.equal(parsed, nil, "Expected non-app scheme to be ignored")
            },
            Stage37ModelCheck(name: "Router applies item deep link to catalog path") {
                let router = Stage37Router()
                router.apply(deepLink: .item("7"))
                try Stage37Assert.equal(router.selectedTab, .catalog, "Expected catalog tab")
                try Stage37Assert.equal(router.catalogPath, [.item("7")], "Expected path replacement with item route")
            },
            Stage37ModelCheck(name: "Router applies search deep link") {
                let router = Stage37Router()
                router.apply(deepLink: .search("layout"))
                try Stage37Assert.equal(router.selectedTab, .search, "Expected search tab")
                try Stage37Assert.equal(router.searchQuery, "layout", "Expected search query projection")
            },
            Stage37ModelCheck(name: "Logout clears protected navigation") {
                let router = Stage37Router()
                router.apply(deepLink: .item("99"))

                let session = Stage37Session(isAuthenticated: true)
                session.logout(router: router)

                try Stage37Assert.equal(session.isAuthenticated, false, "Expected signed-out session")
                try Stage37Assert.equal(router.selectedTab, .home, "Expected reset to home")
                try Stage37Assert.equal(router.catalogPath.isEmpty, true, "Expected empty protected path")
                try Stage37Assert.equal(router.searchQuery, "", "Expected cleared query")
            }
        ]
    }
}

private struct Stage37ModelCheck {
    let name: String
    let run: () throws -> Void
}

private enum Stage37Assert {
    static func equal<T: Equatable>(_ value: T, _ expected: T, _ message: String) throws {
        guard value == expected else {
            throw Stage37CheckError.failed("\(message). Actual: \(value), expected: \(expected)")
        }
    }
}

private enum Stage37CheckError: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

private enum Stage37Tab: String, Equatable {
    case home
    case catalog
    case search
}

private enum Stage37CatalogRoute: Equatable {
    case item(String)
}

private enum Stage37DeepLink: Equatable {
    case item(String)
    case search(String)
}

private struct Stage37DeepLinkParser {
    func parse(urlString: String) -> Stage37DeepLink? {
        guard let components = URLComponents(string: urlString),
              components.scheme?.lowercased() == "switui-elements" else {
            return nil
        }

        let host = components.host?.lowercased() ?? ""
        switch host {
        case "item":
            guard let id = components.path.split(separator: "/").first.map(String.init), !id.isEmpty else {
                return nil
            }
            return .item(id)
        case "search":
            let query = components.queryItems?
                .first(where: { $0.name == "q" })?
                .value?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let query, !query.isEmpty else {
                return nil
            }
            return .search(query)
        default:
            return nil
        }
    }
}

@MainActor
@Observable
private final class Stage37Router {
    var selectedTab: Stage37Tab = .home
    var catalogPath: [Stage37CatalogRoute] = []
    var searchQuery = ""

    func apply(deepLink: Stage37DeepLink) {
        switch deepLink {
        case .item(let id):
            selectedTab = .catalog
            catalogPath = [.item(id)]
        case .search(let query):
            selectedTab = .search
            searchQuery = query
        }
    }

    func resetForLogout() {
        selectedTab = .home
        catalogPath.removeAll()
        searchQuery = ""
    }
}

@MainActor
@Observable
private final class Stage37Session {
    var isAuthenticated: Bool

    init(isAuthenticated: Bool) {
        self.isAuthenticated = isAuthenticated
    }

    func logout(router: Stage37Router) {
        isAuthenticated = false
        router.resetForLogout()
    }
}

#Preview("Stage 37") {
    Stage37TestingModelDrivenSwiftUIView()
}
