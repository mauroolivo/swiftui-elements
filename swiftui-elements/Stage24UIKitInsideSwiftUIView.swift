import SwiftUI
import UIKit

@MainActor
struct Stage24UIKitInsideSwiftUIView: View {
    @State private var activeExercise: Exercise = .uiviewRepresentable

    enum Exercise: String, CaseIterable, Identifiable {
        case uiviewRepresentable = "UIViewRepresentable"
        case uiviewControllerRepresentable = "UIViewControllerRepresentable"

        var id: Self { self }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stage 24 - UIKit inside SwiftUI")
                .font(.title3.bold())

            Text("Wrap UIKit as synchronization, not reconstruction: SwiftUI owns state, representables keep UIKit in sync via make/update/coordinator/dismantle.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Exercise", selection: $activeExercise) {
                ForEach(Exercise.allCases) { exercise in
                    Text(exercise.rawValue).tag(exercise)
                }
            }
            .pickerStyle(.segmented)

            switch activeExercise {
            case .uiviewRepresentable:
                Stage24UIViewRepresentableExercise()
            case .uiviewControllerRepresentable:
                Stage24UIViewControllerRepresentableExercise()
            }
        }
        .padding()
    }
}

private struct Stage24UIViewRepresentableExercise: View {
    @State private var sliderValue: Double = 0.35
    @State private var isMounted = true
    @State private var isOrangeTint = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Concept")
                .font(.headline)

            Text("`updateUIView` can run many times. It should synchronize UIKit view state from SwiftUI state, not recreate UIKit objects.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Prediction")
                .font(.subheadline.bold())

            Text("Toggle tint and move the slider. Which method should run once, and which method should run repeatedly?")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button(isMounted ? "Unmount Slider" : "Mount Slider") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isMounted.toggle()
                    }
                }
                .buttonStyle(.borderedProminent)

                Toggle("Orange tint", isOn: $isOrangeTint)
            }

            if isMounted {
                Stage24UIKitSlider(
                    value: $sliderValue,
                    tintColor: isOrangeTint ? .systemOrange : .systemBlue
                )
                .frame(height: 44)
                .padding(.horizontal, 8)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
                .transition(.opacity)
            } else {
                Text("Slider is removed. Watch for `dismantleUIView` in the console.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, 8)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
            }

            Text("SwiftUI state value: \(sliderValue.formatted(.number.precision(.fractionLength(2))))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Run: 1) Drag slider. 2) Toggle tint repeatedly. 3) Unmount/remount. Then inspect `makeUIView`, `updateUIView`, and `dismantleUIView` logs.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct Stage24UIViewControllerRepresentableExercise: View {
    @State private var count = 0
    @State private var step = 1
    @State private var isMounted = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Problem")
                .font(.headline)

            Text("A UIKit controller (delegate/target-action style) needs to feed mutations back into SwiftUI source-of-truth state.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Stepper("Step: \(step)", value: $step, in: 1...5)

            HStack {
                Button("Reset Count") { count = 0 }
                    .buttonStyle(.bordered)

                Button(isMounted ? "Unmount Controller" : "Mount Controller") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isMounted.toggle()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            if isMounted {
                Stage24UIKitCounterController(
                    count: $count,
                    step: step,
                    accentColor: .systemIndigo
                )
                .frame(height: 150)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
                .transition(.opacity)
            } else {
                Text("Controller removed. Watch for `dismantleUIViewController` log.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
                    .padding(8)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
            }

            Text("SwiftUI source of truth count: \(count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Explanation: the coordinator translates UIKit events into SwiftUI state changes. `updateUIViewController` keeps UIKit display synchronized when state changes from either side.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct Stage24UIKitSlider: UIViewRepresentable {
    @Binding var value: Double
    let tintColor: UIColor

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }

    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider(frame: .zero)
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        LabLog.event("Stage24UIKitSlider makeUIView")
        return slider
    }

    func updateUIView(_ uiView: UISlider, context: Context) {
        context.coordinator.value = $value

        let floatValue = Float(value)
        if abs(uiView.value - floatValue) > 0.0001 {
            uiView.value = floatValue
        }

        if uiView.minimumTrackTintColor != tintColor {
            uiView.minimumTrackTintColor = tintColor
        }

        LabLog.event("Stage24UIKitSlider updateUIView value=\(value)")
    }

    static func dismantleUIView(_ uiView: UISlider, coordinator: Coordinator) {
        uiView.removeTarget(coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        LabLog.event("Stage24UIKitSlider dismantleUIView")
    }

    final class Coordinator: NSObject {
        var value: Binding<Double>

        init(value: Binding<Double>) {
            self.value = value
        }

        @objc
        func valueChanged(_ sender: UISlider) {
            value.wrappedValue = Double(sender.value)
            LabLog.event("Stage24UIKitSlider coordinator valueChanged=\(sender.value)")
        }
    }
}

private struct Stage24UIKitCounterController: UIViewControllerRepresentable {
    @Binding var count: Int
    var step: Int
    var accentColor: UIColor

    func makeCoordinator() -> Coordinator {
        Coordinator(count: $count, step: step)
    }

    func makeUIViewController(context: Context) -> Stage24CounterViewController {
        let viewController = Stage24CounterViewController()
        viewController.delegate = context.coordinator
        viewController.displayedCount = count
        viewController.applyAccent(accentColor)
        LabLog.event("Stage24UIKitCounterController makeUIViewController")
        return viewController
    }

    func updateUIViewController(_ uiViewController: Stage24CounterViewController, context: Context) {
        context.coordinator.count = $count
        context.coordinator.step = step

        uiViewController.delegate = context.coordinator
        uiViewController.displayedCount = count
        uiViewController.applyAccent(accentColor)

        LabLog.event("Stage24UIKitCounterController updateUIViewController count=\(count) step=\(step)")
    }

    static func dismantleUIViewController(_ uiViewController: Stage24CounterViewController, coordinator: Coordinator) {
        uiViewController.delegate = nil
        LabLog.event("Stage24UIKitCounterController dismantleUIViewController")
    }

    final class Coordinator: NSObject, Stage24CounterViewControllerDelegate {
        var count: Binding<Int>
        var step: Int

        init(count: Binding<Int>, step: Int) {
            self.count = count
            self.step = step
        }

        func counterViewControllerDidTapIncrement(_ controller: Stage24CounterViewController) {
            count.wrappedValue += step
            LabLog.event("Stage24UIKitCounterController coordinator increment by \(step)")
        }
    }
}

private protocol Stage24CounterViewControllerDelegate: AnyObject {
    func counterViewControllerDidTapIncrement(_ controller: Stage24CounterViewController)
}

private final class Stage24CounterViewController: UIViewController {
    weak var delegate: Stage24CounterViewControllerDelegate?

    var displayedCount: Int = 0 {
        didSet {
            countLabel.text = "UIKit count: \(displayedCount)"
        }
    }

    private let countLabel = UILabel()
    private let incrementButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()

        view.layer.cornerRadius = 10

        countLabel.font = .preferredFont(forTextStyle: .headline)
        countLabel.textColor = .label
        countLabel.textAlignment = .center

        incrementButton.setTitle("UIKit + Step", for: .normal)
        incrementButton.addTarget(self, action: #selector(incrementTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [countLabel, incrementButton])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        countLabel.text = "UIKit count: \(displayedCount)"
    }

    func applyAccent(_ color: UIColor) {
        incrementButton.tintColor = color
        view.backgroundColor = color.withAlphaComponent(0.10)
    }

    @objc
    private func incrementTapped() {
        if delegate == nil {
            LabLog.event("Stage24CounterViewController increment tapped but delegate is nil")
        }
        delegate?.counterViewControllerDidTapIncrement(self)
    }
}

#Preview {
    Stage24UIKitInsideSwiftUIView()
}
