import Observation
import SwiftUI
import UIKit

@MainActor
struct Stage25SwiftUIInsideUIKitView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Stage 25 - SwiftUI inside UIKit")
                    .font(.title3.bold())

                Text("UIKit owns the screen and navigation. SwiftUI is hosted inside a UIHostingController, so the hosted view can update state while UIKit stays in control of presentation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Prediction")
                    .font(.headline)

                Text("Tap the UIKit buttons first, then interact with the hosted SwiftUI screen. Which side owns the navigation stack, and which side owns the editable state?")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Stage25UIKitHostSurface()
                    .frame(height: 440)
            }
            .padding()
        }
    }
}

private struct Stage25UIKitHostSurface: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        UINavigationController(rootViewController: Stage25UIKitRootViewController())
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        LabLog.event("Stage25UIKitHostSurface updateUIViewController")
    }
}

@MainActor
private final class Stage25UIKitRootViewController: UIViewController {
    private enum PresentationMode: String {
        case push = "Push"
        case modal = "Modal"
    }

    private let titleLabel = UILabel()
    private let explanationLabel = UILabel()
    private let statusLabel = UILabel()
    private let buttonStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        LabLog.event("Stage25UIKitRootViewController viewDidLoad")

        view.backgroundColor = .systemBackground
        title = "Stage 25"

        titleLabel.text = "UIKit root controller"
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.numberOfLines = 0

        explanationLabel.text = "This controller creates UIHostingController instances and decides whether to present or push them. The SwiftUI screen edits UIKit-owned model state through @Bindable."
        explanationLabel.font = .preferredFont(forTextStyle: .footnote)
        explanationLabel.textColor = .secondaryLabel
        explanationLabel.numberOfLines = 0

        statusLabel.text = "No SwiftUI screen is active yet."
        statusLabel.font = .preferredFont(forTextStyle: .caption1)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0

        buttonStack.axis = .vertical
        buttonStack.spacing = 10

        let pushButton = makeButton(title: "Push SwiftUI screen", action: #selector(pushSwiftUIScreen))
        let modalButton = makeButton(title: "Present SwiftUI screen", action: #selector(presentSwiftUIScreen))
        buttonStack.addArrangedSubview(pushButton)
        buttonStack.addArrangedSubview(modalButton)

        let stack = UIStackView(arrangedSubviews: [titleLabel, explanationLabel, buttonStack, statusLabel])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    deinit {
        LabLog.event("Stage25UIKitRootViewController deinit")
    }

    @objc
    private func pushSwiftUIScreen() {
        statusLabel.text = "Pushing a UIHostingController into the UIKit navigation stack."
        LabLog.event("Stage25UIKitRootViewController pushSwiftUIScreen")
        navigationController?.pushViewController(makeHostedController(mode: .push), animated: true)
    }

    @objc
    private func presentSwiftUIScreen() {
        statusLabel.text = "Presenting a UIHostingController inside a UIKit navigation controller."
        LabLog.event("Stage25UIKitRootViewController presentSwiftUIScreen")

        let modalNavigationController = UINavigationController(rootViewController: makeHostedController(mode: .modal))
        present(modalNavigationController, animated: true)
    }

    private func makeHostedController(mode: PresentationMode) -> UIHostingController<Stage25HostedSwiftUIScreen> {
        let model = Stage25HostedScreenModel(source: mode.rawValue)
        var hostingController: UIHostingController<Stage25HostedSwiftUIScreen>!

        hostingController = UIHostingController(
            rootView: Stage25HostedSwiftUIScreen(
                model: model,
                source: mode.rawValue,
                onOpenUIKitDetail: { [weak self] in
                    self?.navigationController?.pushViewController(Stage25UIKitDetailViewController(source: mode.rawValue), animated: true)
                },
                onClose: { [weak hostingController] in
                    switch mode {
                    case .push:
                        hostingController?.navigationController?.popViewController(animated: true)
                    case .modal:
                        hostingController?.dismiss(animated: true)
                    }
                }
            )
        )

        hostingController.title = "SwiftUI \(mode.rawValue)"
        LabLog.event("Stage25UIKitRootViewController made hosted controller for \(mode.rawValue)")
        return hostingController
    }

    private func makeButton(title: String, action: Selector) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.cornerStyle = .medium

        let button = UIButton(configuration: configuration, primaryAction: nil)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
}

private final class Stage25UIKitDetailViewController: UIViewController {
    private let source: String

    init(source: String) {
        self.source = source
        super.init(nibName: nil, bundle: nil)
        LabLog.event("Stage25UIKitDetailViewController init from \(source)")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        LabLog.event("Stage25UIKitDetailViewController viewDidLoad from \(source)")
        view.backgroundColor = .systemGroupedBackground
        title = "UIKit detail"

        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = "This is a plain UIKit detail screen pushed from a SwiftUI button.\n\nPresentation source: \(source)"
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    deinit {
        LabLog.event("Stage25UIKitDetailViewController deinit from \(source)")
    }
}

@Observable
private final class Stage25HostedScreenModel {
    var title: String = "Hosted SwiftUI screen"
    var counter: Int = 0
    var notes: String = "UIKit owns the container; SwiftUI owns the local interaction state."

    init(source: String) {
        title = "Hosted in \(source) mode"
        LabLog.event("Stage25HostedScreenModel init for \(source)")
    }

    deinit {
        LabLog.event("Stage25HostedScreenModel deinit")
    }

    func increment() {
        counter += 1
        LabLog.event("Stage25HostedScreenModel increment -> \(counter)")
    }

    func reset() {
        counter = 0
        notes = "Counter reset from the hosted SwiftUI view."
        LabLog.event("Stage25HostedScreenModel reset")
    }
}

private struct Stage25HostedSwiftUIScreen: View {
    @Bindable var model: Stage25HostedScreenModel
    let source: String
    let onOpenUIKitDetail: () -> Void
    let onClose: () -> Void

    init(
        model: Stage25HostedScreenModel,
        source: String,
        onOpenUIKitDetail: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.model = model
        self.source = source
        self.onOpenUIKitDetail = onOpenUIKitDetail
        self.onClose = onClose
        LabLog.event("Stage25HostedSwiftUIScreen init for \(source)")
    }

    var body: some View {
        let _ = LabLog.event("Stage25HostedSwiftUIScreen body for \(source)")

        VStack(alignment: .leading, spacing: 12) {
            Text("SwiftUI hosted by UIKit")
                .font(.headline)

            Text("The view value is lightweight, but the hosting controller owns its lifetime. Changes in this screen stay inside the UIKit presentation until UIKit dismisses or pops it.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Title", text: $model.title)
                .textFieldStyle(.roundedBorder)

            Stepper("Counter: \(model.counter)", value: $model.counter, in: 0...10)

            Text(model.notes)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Increment") {
                    model.increment()
                }
                .buttonStyle(.bordered)

                Button("Reset") {
                    model.reset()
                }
                .buttonStyle(.bordered)
            }

            Button("Open UIKit detail") {
                onOpenUIKitDetail()
            }
            .buttonStyle(.borderedProminent)

            Button("Close hosted screen") {
                onClose()
            }
            .buttonStyle(.bordered)

            Text("Source: \(source)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            LabLog.event("Stage25HostedSwiftUIScreen onAppear for \(source)")
        }
        .onDisappear {
            LabLog.event("Stage25HostedSwiftUIScreen onDisappear for \(source)")
        }
    }
}

#Preview {
    Stage25SwiftUIInsideUIKitView()
}
