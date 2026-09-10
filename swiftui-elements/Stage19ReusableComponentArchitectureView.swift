import SwiftUI

@MainActor
struct Stage19ReusableComponentArchitectureView: View {
    @State private var compositionMode: Stage19CompositionMode = .parameters
    @State private var showEmptyExample = false
    @State private var loadState: Stage19LoadState<[CatalogItem]> = .idle

    init() {
        LabLog.event("Stage19ReusableComponentArchitectureView init")
    }

    var body: some View {
        let _ = LabLog.event("Stage19ReusableComponentArchitectureView body")

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    concept
                    problem
                    prediction
                    implementation
                    takeaway
                }
                .padding()
            }
            .navigationTitle("Stage 19 Components")
        }
    }

    private var concept: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reusable components are API design")
                .font(.headline)

            Text("A component is not just styling. It is a small semantic contract: what state it owns, what it exposes, and what extension mechanism it allows.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var problem: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Problem")
                .font(.headline)

            Text("Build a tiny design system for a feature card with actions, status badges, empty-state fallback, and async loading.")
                .font(.subheadline)

            Text("UIKit instinct: one giant highly-configurable widget. SwiftUI approach: compose small semantic pieces and choose the right extension point per behavior.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var prediction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prediction")
                .font(.headline)

            Text("Before interacting: which API style will stay easiest to evolve when requirements change - large parameter list, ViewBuilder composition, or style modifier?")
                .font(.subheadline)

            Text("Also predict where loading state should live: inside the button/card component, or at feature scope with a projected rendering component.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var implementation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Implementation sandbox")
                .font(.headline)

            Picker("Composition", selection: $compositionMode) {
                ForEach(Stage19CompositionMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Force empty state", isOn: $showEmptyExample)

            Stage19Card(content: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Catalog")
                            .font(.headline)

                        Spacer()

                        Stage19Badge(text: "beta", tone: .info)
                    }

                    Text("Reusable parts remain small: card container, semantic button, badge, empty state, and async renderer.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    actionDemo
                }
            })

            Stage19AsyncContent(
                state: loadState,
                loaded: { items in
                    if showEmptyExample {
                        Stage19EmptyState(
                            title: "No Results",
                            message: "Try a broader query or clear your filter.",
                            actionTitle: "Reset"
                        ) {
                            showEmptyExample = false
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Loaded items")
                                .font(.subheadline.weight(.semibold))

                            ForEach(items) { item in
                                HStack {
                                    Text(item.title)
                                    Spacer()
                                    Stage19Badge(text: "new", tone: .success)
                                }
                                .font(.caption)
                            }
                        }
                    }
                },
                loading: {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Loading catalog...")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                },
                failed: { message in
                    Stage19EmptyState(
                        title: "Load Failed",
                        message: message,
                        actionTitle: "Retry"
                    ) {
                        triggerLoad(simulateFailure: false)
                    }
                }
            )

            HStack(spacing: 10) {
                Stage19PrimaryButton(
                    title: "Load Success",
                    tone: .primary,
                    action: {
                        triggerLoad(simulateFailure: false)
                    }
                )

                Stage19PrimaryButton(
                    title: "Load Failure",
                    tone: .danger,
                    action: {
                        triggerLoad(simulateFailure: true)
                    }
                )
            }

            Text("Notice that Stage19AsyncContent does not fetch data. It only renders state. Fetching stays at feature scope.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    @ViewBuilder
    private var actionDemo: some View {
        switch compositionMode {
        case .parameters:
            Stage19PrimaryButton(
                title: "Parameter-based button",
                systemImage: "slider.horizontal.3",
                tone: .primary,
                action: {
                    LabLog.event("Stage19 parameters action tapped")
                }
            )

        case .viewBuilder:
            Stage19PrimaryButton(
                tone: .primary,
                label: {
                    Label("ViewBuilder content", systemImage: "square.stack.3d.up")
                },
                action: {
                    LabLog.event("Stage19 viewBuilder action tapped")
                }
            )

        case .modifier:
            Button(
                action: {
                    LabLog.event("Stage19 modifier action tapped")
                },
                label: {
                    Label("Modifier-styled button", systemImage: "paintbrush")
                }
            )
            .stage19ProminentButton(tone: .primary)
        }
    }

    private var takeaway: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Prefer small semantic components over one giant configurable view.", systemImage: "square.grid.2x2")
            Label("Choose extension point by responsibility: data/behavior via parameters, structure via ViewBuilder, visual policy via style/modifier.", systemImage: "slider.horizontal.3")
            Label("Keep async state ownership at feature level; keep rendering helpers stateless.", systemImage: "arrow.triangle.branch")
        }
        .font(.caption)
        .stageCard()
    }

    private func triggerLoad(simulateFailure: Bool) {
        loadState = .loading

        Task {
            try? await Task.sleep(for: .milliseconds(450))

            if simulateFailure {
                loadState = .failed("The preview repository timed out.")
                LabLog.event("Stage19 simulated load failure")
            } else {
                loadState = .loaded(CatalogItem.samples)
                LabLog.event("Stage19 simulated load success")
            }
        }
    }
}

private enum Stage19CompositionMode: String, CaseIterable, Identifiable {
    case parameters = "Parameters"
    case viewBuilder = "ViewBuilder"
    case modifier = "Modifier"

    var id: Self { self }
}

private enum Stage19LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}

private struct Stage19Card<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct Stage19PrimaryButton<LabelContent: View>: View {
    let tone: Stage19PrimaryTone
    let action: () -> Void
    @ViewBuilder let label: () -> LabelContent

    init(
        title: String,
        systemImage: String? = nil,
        tone: Stage19PrimaryTone = .primary,
        action: @escaping () -> Void
    ) where LabelContent == AnyView {
        self.tone = tone
        self.action = action

        self.label = {
            if let systemImage {
                AnyView(Label(title, systemImage: systemImage))
            } else {
                AnyView(Text(title))
            }
        }
    }

    init(
        tone: Stage19PrimaryTone = .primary,
        @ViewBuilder label: @escaping () -> LabelContent,
        action: @escaping () -> Void
    ) {
        self.tone = tone
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            label()
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(Stage19FilledButtonStyle(tone: tone))
    }
}

private enum Stage19PrimaryTone {
    case primary
    case danger

    var background: Color {
        switch self {
        case .primary: return .accentColor
        case .danger: return .red
        }
    }
}

private struct Stage19FilledButtonStyle: ButtonStyle {
    let tone: Stage19PrimaryTone

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(tone.background.opacity(configuration.isPressed ? 0.7 : 1))
            )
    }
}

private extension View {
    func stage19ProminentButton(tone: Stage19PrimaryTone) -> some View {
        buttonStyle(Stage19FilledButtonStyle(tone: tone))
    }
}

private struct Stage19Badge: View {
    let text: String
    let tone: Stage19BadgeTone

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(tone.foreground)
            .background(tone.background, in: Capsule())
    }
}

private enum Stage19BadgeTone {
    case info
    case success

    var foreground: Color {
        switch self {
        case .info: return .blue
        case .success: return .green
        }
    }

    var background: Color {
        switch self {
        case .info: return .blue.opacity(0.16)
        case .success: return .green.opacity(0.16)
        }
    }
}

private struct Stage19EmptyState: View {
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct Stage19AsyncContent<Value>: View {
    let state: Stage19LoadState<Value>
    private let loaded: (Value) -> AnyView
    private let loading: () -> AnyView
    private let failed: (String) -> AnyView

    init<Loaded: View, Loading: View, Failed: View>(
        state: Stage19LoadState<Value>,
        @ViewBuilder loaded: @escaping (Value) -> Loaded,
        @ViewBuilder loading: @escaping () -> Loading,
        @ViewBuilder failed: @escaping (String) -> Failed
    ) {
        self.state = state
        self.loaded = { AnyView(loaded($0)) }
        self.loading = { AnyView(loading()) }
        self.failed = { AnyView(failed($0)) }
    }

    var body: some View {
        switch state {
        case .idle:
            Stage19EmptyState(
                title: "Idle",
                message: "Trigger a load to render this feature state."
            )

        case .loading:
            loading()

        case let .loaded(value):
            loaded(value)

        case let .failed(message):
            failed(message)
        }
    }
}

#Preview("Stage 19 reusable components") {
    Stage19ReusableComponentArchitectureView()
}
