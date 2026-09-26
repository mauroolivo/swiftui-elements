import Observation
import SwiftUI
import UIKit

@MainActor
struct Stage28ObservationSharedBetweenUIKitAndSwiftUIView: View {
    @State private var model = Stage28SharedPlayerModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Stage 28 - Observation shared between UIKit and SwiftUI")
                    .font(.title3.bold())

                Text("One @Observable model can stay alive while both frameworks read and mutate it. SwiftUI gets dependency tracking from body reads; UIKit must opt into tracking explicitly.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Concept")
                        .font(.headline)
                    Text("Observation is separate from ownership. The shared model below is owned once at the stage root, but both UIKit and SwiftUI can depend on it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Problem")
                        .font(.headline)
                    Text("During migration, a legacy UIKit screen and a new SwiftUI screen may need the same mutable feature state. Rewriting the model layer just because the rendering framework changed would create unnecessary risk.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Prediction")
                        .font(.headline)
                    Text("Open the console, then change only the volume from one framework. Which render logs fire: the playback readers, the volume readers, or both?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .stageCard()

                Stage28SharedStateSummary(model: model)

                Stage28SwiftUISurface(model: model)

                Stage28UIKitSurface(model: model)
                    .frame(height: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.quaternary)
                    }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Explanation")
                        .font(.headline)

                    Text("SwiftUI tracks exactly which observable properties each view body reads. UIKit does not get that automatically, so the view controller uses withObservationTracking to subscribe to specific property reads and re-render only the affected section.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Takeaway")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Keep one source of truth even while presentation is split across frameworks.")
                        Text("• Observation works across UIKit and SwiftUI, but UIKit needs an explicit bridge.")
                        Text("• Migration usually changes UI ownership first; shared feature models can stay put.")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .stageCard()
            }
            .padding()
        }
    }
}

@MainActor
@Observable
private final class Stage28SharedPlayerModel {
    var currentTrackTitle: String
    var isPlaying: Bool
    var volume: Double
    var playCount: Int
    var lastActionSource: String
    var eventLog: [String]

    init(
        currentTrackTitle: String = "Observation Jam",
        isPlaying: Bool = false,
        volume: Double = 0.35,
        playCount: Int = 0,
        lastActionSource: String = "None yet"
    ) {
        self.currentTrackTitle = currentTrackTitle
        self.isPlaying = isPlaying
        self.volume = volume
        self.playCount = playCount
        self.lastActionSource = lastActionSource
        self.eventLog = []
        record("Model initialized")
        LabLog.event("Stage28SharedPlayerModel init")
    }

    deinit {
        LabLog.event("Stage28SharedPlayerModel deinit")
    }

    func togglePlayback(source: String) {
        isPlaying.toggle()
        if isPlaying {
            playCount += 1
        }
        lastActionSource = source
        record("\(source) toggled playback -> \(isPlaying ? "playing" : "paused")")
    }

    func renameTrack(_ title: String, source: String) {
        currentTrackTitle = title.isEmpty ? "Untitled draft" : title
        lastActionSource = source
        record("\(source) renamed track -> \(currentTrackTitle)")
    }

    func setVolume(_ newValue: Double, source: String) {
        let clamped = min(max(newValue, 0), 1)
        volume = clamped
        lastActionSource = source
        record("\(source) set volume -> \(Int(clamped * 100))%")
    }

    func resetDemoState() {
        currentTrackTitle = "Observation Jam"
        isPlaying = false
        volume = 0.35
        playCount = 0
        lastActionSource = "Reset button"
        eventLog.removeAll(keepingCapacity: true)
        record("Demo state reset")
    }

    private func record(_ message: String) {
        eventLog.insert(message, at: 0)
        LabLog.event("Stage28SharedPlayerModel: \(message)")
    }
}

private struct Stage28SharedStateSummary: View {
    let model: Stage28SharedPlayerModel

    var body: some View {
        let _ = LabLog.event("Stage28SharedStateSummary body")

        VStack(alignment: .leading, spacing: 10) {
            Text("Shared model snapshot")
                .font(.headline)

            Text("This single model instance is owned by the SwiftUI stage root. Both surfaces mutate the same values.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Track: \(model.currentTrackTitle)")
                .font(.subheadline.bold())
            Text("Status: \(model.isPlaying ? "Playing" : "Paused")")
                .font(.caption)
            Text("Volume: \(Int(model.volume * 100))%")
                .font(.caption)
            Text("Play count: \(model.playCount)")
                .font(.caption)
            Text("Last action source: \(model.lastActionSource)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Reset shared model") {
                model.resetDemoState()
            }
            .buttonStyle(.bordered)
        }
        .stageCard()
    }
}

private struct Stage28SwiftUISurface: View {
    let model: Stage28SharedPlayerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SwiftUI surface")
                .font(.headline)

            Text("These subviews automatically create observation dependencies from the properties they read in body. Watch the console logs while you edit.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Stage28SwiftUIPlaybackSection(model: model)
            Stage28SwiftUIVolumeSection(model: model)
            Stage28EventLogSection(model: model)
        }
        .stageCard()
    }
}

private struct Stage28SwiftUIPlaybackSection: View {
    let model: Stage28SharedPlayerModel

    init(model: Stage28SharedPlayerModel) {
        self.model = model
        LabLog.event("Stage28SwiftUIPlaybackSection init")
    }

    var body: some View {
        let _ = LabLog.event("Stage28SwiftUIPlaybackSection body")

        VStack(alignment: .leading, spacing: 8) {
            Text("Playback + title reader")
                .font(.subheadline.bold())

            TextField(
                "Track title",
                text: Binding(
                    get: { model.currentTrackTitle },
                    set: { model.renameTrack($0, source: "SwiftUI TextField") }
                )
            )
            .textFieldStyle(.roundedBorder)

            Text(model.isPlaying ? "Now playing" : "Currently paused")
                .font(.caption)
            Text("Play count: \(model.playCount)")
                .font(.caption)
            Text("Last action: \(model.lastActionSource)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button(model.isPlaying ? "Pause from SwiftUI" : "Play from SwiftUI") {
                    model.togglePlayback(source: "SwiftUI button")
                }
                .buttonStyle(.borderedProminent)

                Button("Rename to SwiftUI Mix") {
                    model.renameTrack("SwiftUI Mix", source: "SwiftUI preset")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct Stage28SwiftUIVolumeSection: View {
    let model: Stage28SharedPlayerModel

    init(model: Stage28SharedPlayerModel) {
        self.model = model
        LabLog.event("Stage28SwiftUIVolumeSection init")
    }

    var body: some View {
        let _ = LabLog.event("Stage28SwiftUIVolumeSection body")

        VStack(alignment: .leading, spacing: 8) {
            Text("Volume reader")
                .font(.subheadline.bold())

            Slider(
                value: Binding(
                    get: { model.volume },
                    set: { model.setVolume($0, source: "SwiftUI slider") }
                ),
                in: 0...1
            )

            Text("Volume: \(Int(model.volume * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("25%") {
                    model.setVolume(0.25, source: "SwiftUI quick preset")
                }
                .buttonStyle(.bordered)

                Button("80%") {
                    model.setVolume(0.8, source: "SwiftUI quick preset")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct Stage28EventLogSection: View {
    let model: Stage28SharedPlayerModel

    var body: some View {
        let _ = LabLog.event("Stage28EventLogSection body")

        VStack(alignment: .leading, spacing: 8) {
            Text("Shared event log")
                .font(.subheadline.bold())

            ForEach(Array(model.eventLog.prefix(6).enumerated()), id: \.offset) { _, event in
                Text(event)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct Stage28UIKitSurface: UIViewControllerRepresentable {
    let model: Stage28SharedPlayerModel

    func makeUIViewController(context: Context) -> Stage28UIKitObservationViewController {
        Stage28UIKitObservationViewController(model: model)
    }

    func updateUIViewController(_ uiViewController: Stage28UIKitObservationViewController, context: Context) {
        uiViewController.refreshExplanation()
    }
}

@MainActor
private final class Stage28UIKitObservationViewController: UIViewController {
    private let model: Stage28SharedPlayerModel

    private let explanationLabel = UILabel()
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let playbackRenderCountLabel = UILabel()
    private let lastActionLabel = UILabel()
    private let playPauseButton = UIButton(type: .system)
    private let renameButton = UIButton(type: .system)
    private let volumeLabel = UILabel()
    private let volumeRenderCountLabel = UILabel()
    private let volumeSlider = UISlider(frame: .zero)
    private let quieterButton = UIButton(type: .system)
    private let louderButton = UIButton(type: .system)

    private var playbackRenderCount = 0
    private var volumeRenderCount = 0

    init(model: Stage28SharedPlayerModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
        LabLog.event("Stage28UIKitObservationViewController init")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureUI()
        refreshExplanation()
        observePlaybackSection()
        observeVolumeSection()
    }

    deinit {
        LabLog.event("Stage28UIKitObservationViewController deinit")
    }

    func refreshExplanation() {
        explanationLabel.text = "UIKit surface: withObservationTracking bridges the same @Observable model into UILabel / UIButton / UISlider updates."
    }

    private func configureUI() {
        let headerLabel = makeLabel(font: .preferredFont(forTextStyle: .headline))
        headerLabel.text = "UIKit surface"

        explanationLabel.font = .preferredFont(forTextStyle: .caption1)
        explanationLabel.textColor = .secondaryLabel
        explanationLabel.numberOfLines = 0

        titleLabel.font = .preferredFont(forTextStyle: .title3)
        titleLabel.numberOfLines = 0

        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.textColor = .label
        statusLabel.numberOfLines = 0

        lastActionLabel.font = .preferredFont(forTextStyle: .caption1)
        lastActionLabel.textColor = .secondaryLabel
        lastActionLabel.numberOfLines = 0

        playbackRenderCountLabel.font = .preferredFont(forTextStyle: .caption2)
        playbackRenderCountLabel.textColor = .secondaryLabel

        volumeLabel.font = .preferredFont(forTextStyle: .subheadline)
        volumeLabel.numberOfLines = 1

        volumeRenderCountLabel.font = .preferredFont(forTextStyle: .caption2)
        volumeRenderCountLabel.textColor = .secondaryLabel

        configureButton(playPauseButton, title: "Play / Pause", action: #selector(togglePlayback))
        configureButton(renameButton, title: "Rename to UIKit Remix", action: #selector(renameTrack))
        configureButton(quieterButton, title: "-10%", action: #selector(lowerVolume))
        configureButton(louderButton, title: "+10%", action: #selector(raiseVolume))

        volumeSlider.minimumValue = 0
        volumeSlider.maximumValue = 1
        volumeSlider.addTarget(self, action: #selector(volumeChanged(_:)), for: .valueChanged)

        let playbackButtons = UIStackView(arrangedSubviews: [playPauseButton, renameButton])
        playbackButtons.axis = .horizontal
        playbackButtons.spacing = 8
        playbackButtons.distribution = .fillEqually

        let volumeButtons = UIStackView(arrangedSubviews: [quieterButton, louderButton])
        volumeButtons.axis = .horizontal
        volumeButtons.spacing = 8
        volumeButtons.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [
            headerLabel,
            explanationLabel,
            titleLabel,
            statusLabel,
            playbackRenderCountLabel,
            lastActionLabel,
            playbackButtons,
            volumeLabel,
            volumeRenderCountLabel,
            volumeSlider,
            volumeButtons
        ])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    private func observePlaybackSection() {
        withObservationTracking {
            renderPlaybackSection()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observePlaybackSection()
            }
        }
    }

    private func observeVolumeSection() {
        withObservationTracking {
            renderVolumeSection()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeVolumeSection()
            }
        }
    }

    private func renderPlaybackSection() {
        playbackRenderCount += 1
        titleLabel.text = model.currentTrackTitle
        statusLabel.text = model.isPlaying ? "Now playing" : "Currently paused"
        lastActionLabel.text = "Last action: \(model.lastActionSource)"
        playbackRenderCountLabel.text = "UIKit playback section renders: \(playbackRenderCount)"
        playPauseButton.setTitle(model.isPlaying ? "Pause from UIKit" : "Play from UIKit", for: .normal)
        LabLog.event("Stage28UIKitObservationViewController renderPlaybackSection")
    }

    private func renderVolumeSection() {
        volumeRenderCount += 1
        volumeLabel.text = "Volume: \(Int(model.volume * 100))%"
        volumeRenderCountLabel.text = "UIKit volume section renders: \(volumeRenderCount)"
        volumeSlider.value = Float(model.volume)
        LabLog.event("Stage28UIKitObservationViewController renderVolumeSection")
    }

    @objc
    private func togglePlayback() {
        model.togglePlayback(source: "UIKit button")
    }

    @objc
    private func renameTrack() {
        model.renameTrack("UIKit Remix", source: "UIKit button")
    }

    @objc
    private func lowerVolume() {
        model.setVolume(model.volume - 0.1, source: "UIKit button")
    }

    @objc
    private func raiseVolume() {
        model.setVolume(model.volume + 0.1, source: "UIKit button")
    }

    @objc
    private func volumeChanged(_ sender: UISlider) {
        model.setVolume(Double(sender.value), source: "UIKit slider")
    }

    private func makeLabel(font: UIFont) -> UILabel {
        let label = UILabel()
        label.font = font
        label.numberOfLines = 0
        return label
    }

    private func configureButton(_ button: UIButton, title: String, action: Selector) {
        var configuration = UIButton.Configuration.bordered()
        configuration.title = title
        button.configuration = configuration
        button.addTarget(self, action: action, for: .touchUpInside)
    }
}

#Preview {
    Stage28ObservationSharedBetweenUIKitAndSwiftUIView()
}
