import Observation
import SwiftUI

@MainActor
struct Stage31ErrorPresentationView: View {
    @State private var model = Stage31ErrorDemoModel(service: Stage31MockCatalogService())
    @State private var selectedScenario: Stage31Scenario = .success
    @State private var showLegacyAlert = false

    private var typedAlertIsPresented: Binding<Bool> {
        Binding(
            get: { model.errorPresentation != nil },
            set: { isPresented in
                if !isPresented {
                    model.errorPresentation = nil
                }
            }
        )
    }

    private var typedAlertTitle: String {
        model.errorPresentation?.title ?? "Error"
    }

    private var typedAlertMessage: String {
        model.errorPresentation?.message ?? ""
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Stage 31 - Error presentation") {
                    Text("Concept")
                        .font(.headline)
                    Text("Typed app errors let us decide where each failure belongs: inline, screen-level, transient alert, or fatal state.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Problem")
                        .font(.headline)
                    Text("A plain `alert(isPresented:)` boolean cannot encode *which* error happened or what action should be offered.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Prediction")
                        .font(.headline)
                    Text("Pick each scenario and run load. Which ones should be recoverable inline, and which should interrupt with an alert?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Implementation") {
                    Picker("Scenario", selection: $selectedScenario) {
                        ForEach(Stage31Scenario.allCases) { scenario in
                            Text(scenario.label).tag(scenario)
                        }
                    }

                    Button(model.isLoading ? "Loading..." : "Load Catalog") {
                        Task {
                            await model.load(scenario: selectedScenario)
                        }
                    }
                    .disabled(model.isLoading)

                    Button("Retry Last Operation") {
                        Task {
                            await model.retryLast()
                        }
                    }
                    .disabled(model.isLoading || !model.canRetry)

                    Button("Legacy bool alert demo") {
                        showLegacyAlert = true
                    }

                    Text("This screen maps backend errors to typed app errors, then chooses presentation strategy from model state.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let fatalMessage = model.fatalMessage {
                    Section("Fatal state") {
                        Label("Fatal: \(fatalMessage)", systemImage: "exclamationmark.octagon.fill")
                            .foregroundStyle(.red)
                    }
                }

                if let screenFailure = model.screenFailure {
                    Stage31ScreenFailureSection(screenFailure: screenFailure)
                }

                Section("Inline validation") {
                    if let inlineMessage = model.inlineMessage {
                        Label(inlineMessage, systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text("No inline validation error")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Catalog") {
                    if model.isLoading {
                        ProgressView("Loading")
                    } else if model.items.isEmpty {
                        Text("No items loaded")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.items) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.subheadline.bold())
                                Text(item.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section("Run") {
                    Text("1) Try each scenario and observe where the error appears.")
                    Text("2) Use Retry after a screen-level failure.")
                    Text("3) Compare the typed alert with the legacy bool alert.")
                }

                Section("Explanation") {
                    Text("Recoverable validation errors stay close to inputs (inline). Retryable load failures become screen state. Session/auth interruptions use transient alert presentation. Fatal corruption is modeled as distinct state instead of reusing alert booleans.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Refactor") {
                    Text("Move `Stage31ErrorMapper` and `Stage31ErrorPresentation` to shared feature modules when multiple screens need consistent policies.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Takeaway") {
                    Text("- Model typed app errors before choosing UI presentation.")
                    Text("- Use `ErrorPresentation?` for transient alerts with actions.")
                    Text("- Keep inline/screen/fatal failures as explicit state, not one generic boolean.")
                }
            }
            .navigationTitle("Error Presentation")
            .alert("Legacy bool alert", isPresented: $showLegacyAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This bool says nothing about the error type, context, or retry action.")
            }
            .alert(typedAlertTitle, isPresented: typedAlertIsPresented) {
                Button("Dismiss", role: .cancel) {}
                if model.errorPresentation?.showsRetry == true {
                    Button("Retry") {
                        Task {
                            await model.retryLast()
                        }
                    }
                }
            } message: {
                Text(typedAlertMessage)
            }
        }
        .onAppear {
            LabLog.event("Stage31ErrorPresentationView onAppear")
        }
    }
}

private struct Stage31ScreenFailureSection: View {
    let screenFailure: Stage31ScreenFailure

    var body: some View {
        Section("Screen-level failure") {
            Text(screenFailure.title)
                .font(.headline)
            Text(screenFailure.message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

@MainActor
@Observable
private final class Stage31ErrorDemoModel {
    var items: [Stage31CatalogItem] = []
    var isLoading = false
    var inlineMessage: String?
    var screenFailure: Stage31ScreenFailure?
    var fatalMessage: String?
    var errorPresentation: Stage31ErrorPresentation?

    private(set) var canRetry = false
    private var lastScenario: Stage31Scenario = .success
    private let service: any Stage31CatalogService

    init(service: any Stage31CatalogService) {
        self.service = service
    }

    func load(scenario: Stage31Scenario) async {
        guard !isLoading else { return }

        lastScenario = scenario
        clearTransientErrors()
        isLoading = true

        do {
            items = try await service.fetchCatalog(scenario: scenario)
            canRetry = false
        } catch let backendError as Stage31BackendError {
            let appError = Stage31ErrorMapper.map(backendError)
            apply(error: appError)
        } catch {
            apply(error: .fatalDataCorruption)
        }

        isLoading = false
    }

    func retryLast() async {
        await load(scenario: lastScenario)
    }

    private func clearTransientErrors() {
        inlineMessage = nil
        screenFailure = nil
        fatalMessage = nil
        errorPresentation = nil
    }

    private func apply(error: Stage31AppError) {
        switch error {
        case .invalidQuery(let message):
            inlineMessage = message
            canRetry = false
        case .networkUnavailable:
            screenFailure = Stage31ScreenFailure(
                title: "Could not load catalog",
                message: "Check your connection and retry."
            )
            canRetry = true
        case .sessionExpired:
            errorPresentation = Stage31ErrorPresentation(
                title: "Session expired",
                message: "Sign in again or retry after refreshing credentials.",
                showsRetry: true
            )
            canRetry = true
        case .fatalDataCorruption:
            fatalMessage = "Local cache is corrupted. Relaunch or clear persisted data."
            canRetry = false
        }
    }
}

private struct Stage31CatalogItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
}

private enum Stage31Scenario: String, CaseIterable, Identifiable {
    case success
    case invalidQuery
    case networkFailure
    case sessionExpired
    case fatalCorruption

    var id: Self { self }

    var label: String {
        switch self {
        case .success:
            "Success"
        case .invalidQuery:
            "Inline validation"
        case .networkFailure:
            "Screen-level retryable"
        case .sessionExpired:
            "Transient alert"
        case .fatalCorruption:
            "Fatal state"
        }
    }
}

private protocol Stage31CatalogService {
    func fetchCatalog(scenario: Stage31Scenario) async throws -> [Stage31CatalogItem]
}

private struct Stage31MockCatalogService: Stage31CatalogService {
    func fetchCatalog(scenario: Stage31Scenario) async throws -> [Stage31CatalogItem] {
        try await Task.sleep(for: .milliseconds(300))

        switch scenario {
        case .success:
            return [
                Stage31CatalogItem(id: "identity", title: "Identity", subtitle: "Error surfaces are part of feature state."),
                Stage31CatalogItem(id: "ownership", title: "Ownership", subtitle: "The model owns error classification policy."),
                Stage31CatalogItem(id: "recovery", title: "Recovery", subtitle: "Retry behavior is explicit and testable.")
            ]
        case .invalidQuery:
            throw Stage31BackendError.validationFailed
        case .networkFailure:
            throw Stage31BackendError.transportTimeout
        case .sessionExpired:
            throw Stage31BackendError.unauthorized
        case .fatalCorruption:
            throw Stage31BackendError.corruptedPayload
        }
    }
}

private enum Stage31BackendError: Error {
    case validationFailed
    case transportTimeout
    case unauthorized
    case corruptedPayload
}

private enum Stage31AppError: Error {
    case invalidQuery(message: String)
    case networkUnavailable
    case sessionExpired
    case fatalDataCorruption
}

private enum Stage31ErrorMapper {
    static func map(_ backendError: Stage31BackendError) -> Stage31AppError {
        switch backendError {
        case .validationFailed:
            .invalidQuery(message: "Query must contain at least 2 non-space characters.")
        case .transportTimeout:
            .networkUnavailable
        case .unauthorized:
            .sessionExpired
        case .corruptedPayload:
            .fatalDataCorruption
        }
    }
}

private struct Stage31ScreenFailure: Equatable {
    let title: String
    let message: String
}

private struct Stage31ErrorPresentation: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let showsRetry: Bool
}

#Preview("Stage 31") {
    Stage31ErrorPresentationView()
}
