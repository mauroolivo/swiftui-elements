import SwiftUI

@MainActor
struct Stage20ViewModifierStylesEnvironmentView: View {
    @State private var useCompactOverride = false
    @State private var notificationsEnabled = true
    @State private var didSync = false

    init() {
        LabLog.event("Stage20ViewModifierStylesEnvironmentView init")
    }

    var body: some View {
        let _ = LabLog.event("Stage20ViewModifierStylesEnvironmentView body")

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    concept
                    problem
                    prediction
                    implementation
                    refactor
                    takeaway
                }
                .padding()
            }
            .navigationTitle("Stage 20 Styles")
        }
    }

    private var concept: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Styling is a policy layer")
                .font(.headline)

            Text("Use ViewModifier for reusable decoration, Style protocols for control behavior, and environment values for semantic theme tokens.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var problem: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Problem")
                .font(.headline)

            Text("A feature screen needs consistent spacing, button appearance, toggle semantics, and icon-label alignment. Product also asks for a compact variant in only one subtree.")
                .font(.subheadline)

            Text("UIKit instinct: set visual properties per control. SwiftUI approach: model semantic tokens and styles once, then let environment propagation apply policy.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var prediction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prediction")
                .font(.headline)

            Text("Before toggling compact mode: which parts should change when we override a single environment value in a subtree?")
                .font(.subheadline)

            Text("Predict whether the button style and the card modifier will both pick up new spacing/corner/tint tokens automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var implementation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Implementation sandbox")
                .font(.headline)

            Toggle("Use compact token override in preview panel", isOn: $useCompactOverride)
                .toggleStyle(Stage20TintedToggleStyle())

            Stage20SettingsPanel(
                title: "Root theme",
                notificationsEnabled: $notificationsEnabled,
                didSync: $didSync
            )

            Stage20SettingsPanel(
                title: "Scoped compact override",
                notificationsEnabled: $notificationsEnabled,
                didSync: $didSync
            )
            .environment(\.stage20Theme, useCompactOverride ? .compact : .default)

            Text("The second panel overrides only Stage20Theme in its subtree. No booleans or manual property plumbing are needed in children.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var refactor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Refactor lens")
                .font(.headline)

            Text("If every call site passes spacing, corner radius, and tint manually, styling leaks into feature logic. Instead, keep those values in environment tokens and keep feature APIs semantic.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var takeaway: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Use ViewModifier for reusable surface/decoration policy.", systemImage: "square.on.square")
            Label("Use ButtonStyle/ToggleStyle/LabelStyle for control semantics, not one-off tweaks.", systemImage: "switch.2")
            Label("Use environment values as semantic tokens and override them by subtree when needed.", systemImage: "arrow.triangle.branch")
        }
        .font(.caption)
        .stageCard()
    }
}

private struct Stage20SettingsPanel: View {
    let title: String
    @Binding var notificationsEnabled: Bool
    @Binding var didSync: Bool

    @Environment(\.stage20Theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing) {
            Label(title, systemImage: "paintpalette")
                .labelStyle(Stage20IconFirstLabelStyle())

            Toggle("Notifications", isOn: $notificationsEnabled)
                .toggleStyle(Stage20TintedToggleStyle())

            Button(didSync ? "Synced" : "Sync now") {
                didSync.toggle()
                LabLog.event("Stage20 toggled sync state to \(didSync)")
            }
            .buttonStyle(Stage20ProminentButtonStyle())

            Text("spacing: \(Int(theme.spacing)) | corner: \(Int(theme.cornerRadius))")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
        }
        .stage20Card()
    }
}

private struct Stage20Theme: Equatable {
    var spacing: CGFloat
    var cornerRadius: CGFloat
    var accent: Color

    static let `default` = Stage20Theme(spacing: 12, cornerRadius: 14, accent: .accentColor)
    static let compact = Stage20Theme(spacing: 8, cornerRadius: 8, accent: .indigo)
}

private struct Stage20ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: Stage20Theme = .default
}

private extension EnvironmentValues {
    var stage20Theme: Stage20Theme {
        get { self[Stage20ThemeEnvironmentKey.self] }
        set { self[Stage20ThemeEnvironmentKey.self] = newValue }
    }
}

private struct Stage20CardModifier: ViewModifier {
    @Environment(\.stage20Theme) private var theme

    func body(content: Content) -> some View {
        content
            .padding(theme.spacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: theme.cornerRadius))
    }
}

private extension View {
    func stage20Card() -> some View {
        modifier(Stage20CardModifier())
    }
}

private struct Stage20ProminentButtonStyle: ButtonStyle {
    @Environment(\.stage20Theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, max(8, theme.spacing - 2))
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .fill(theme.accent.opacity(configuration.isPressed ? 0.7 : 1))
            )
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

private struct Stage20TintedToggleStyle: ToggleStyle {
    @Environment(\.stage20Theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Button {
                configuration.isOn.toggle()
            } label: {
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .fill(configuration.isOn ? theme.accent : .secondary.opacity(0.25))
                    .frame(width: 52, height: 30)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(.white)
                            .padding(3)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(configuration.isOn ? "On" : "Off")
        }
    }
}

private struct Stage20IconFirstLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
                .foregroundStyle(.secondary)
            configuration.title
                .font(.subheadline.weight(.semibold))
        }
    }
}

#Preview("Stage 20 styles") {
    Stage20ViewModifierStylesEnvironmentView()
}
