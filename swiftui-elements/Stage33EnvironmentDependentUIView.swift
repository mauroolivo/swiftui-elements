import SwiftUI

@MainActor
struct Stage33EnvironmentDependentUIView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var emphasized = false

    private var spacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 20 : 12
    }

    private var cardLayoutDescription: String {
        switch horizontalSizeClass {
        case .compact:
            return "Single-column card stack (compact width)"
        case .regular:
            return "Two-column card grouping (regular width)"
        case .none:
            return "Fallback layout (size class unavailable)"
        @unknown default:
            return "Fallback layout (unknown size class)"
        }
    }

    private var accentStyle: Color {
        colorScheme == .dark ? .mint : .blue
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Stage 33 - Environment-dependent UI") {
                    Text("Concept")
                        .font(.headline)
                    Text("Environment values are contextual inputs resolved where a view is rendered. Prefer adapting from available space and user settings instead of device checks.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Problem")
                        .font(.headline)
                    Text("Hardcoded spacing, layout, and motion assumptions often break in accessibility sizes, dark mode, and split-screen contexts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Prediction")
                        .font(.headline)
                    Text("Before running: which parts should change when you switch Dynamic Type, dark mode, locale, and Reduce Motion?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Implementation") {
                    Text("Resolved environment snapshot")
                        .font(.headline)

                    Stage33EnvironmentSnapshotRow(label: "Color scheme", value: colorScheme == .dark ? "dark" : "light")
                    Stage33EnvironmentSnapshotRow(label: "Dynamic Type", value: "\(dynamicTypeSize)")
                    Stage33EnvironmentSnapshotRow(label: "Horizontal size class", value: horizontalSizeClassLabel)
                    Stage33EnvironmentSnapshotRow(label: "Locale", value: locale.identifier)
                    Stage33EnvironmentSnapshotRow(label: "Reduce Motion", value: reduceMotion ? "enabled" : "disabled")
                }

                Section("Adaptive demo") {
                    Text("\("catalog_items_count".localized(locale: locale)): 3")
                        .font(.subheadline)

                    VStack(alignment: .leading, spacing: spacing) {
                        Stage33AdaptiveCard(title: "Identity", detail: "Stable IDs prevent accidental state reset.", accent: accentStyle)
                        Stage33AdaptiveCard(title: "Ownership", detail: "State belongs to the smallest scope that can own it.", accent: accentStyle)
                        Stage33AdaptiveCard(title: "Dependencies", detail: "Read only the environment values your UI actually needs.", accent: accentStyle)
                    }
                    .opacity(emphasized ? 1 : 0.86)

                    Button(reduceMotion ? "Toggle emphasis (no animation)" : "Toggle emphasis") {
                        if reduceMotion {
                            emphasized.toggle()
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                emphasized.toggle()
                            }
                        }
                    }

                    Text(cardLayoutDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Run") {
                    Text("1) Run the app, then switch between light/dark mode in Simulator.")
                    Text("2) Increase Dynamic Type to an accessibility size.")
                    Text("3) Toggle Reduce Motion in iOS Settings > Accessibility.")
                    Text("4) Change Preview locale to verify localized text projection.")
                }

                Section("Explanation") {
                    Text("`@Environment` does not mean global state ownership. It is contextual dependency lookup. Parent context and system settings shape child rendering, while your feature state still owns business behavior.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Refactor") {
                    Text("If multiple features need the same adaptation rules, extract semantic tokens (for spacing/typography/colors) into environment-backed theme values instead of repeating `if` checks.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Takeaway") {
                    Text("- Adapt using environment + available space, not `if iPhone` checks.")
                    Text("- Environment provides dependencies; it does not change ownership automatically.")
                    Text("- Accessibility values are first-class runtime inputs, not edge cases.")
                }
            }
            .navigationTitle("Environment UI")
        }
        .onAppear {
            LabLog.event("Stage33EnvironmentDependentUIView onAppear")
        }
    }

    private var horizontalSizeClassLabel: String {
        switch horizontalSizeClass {
        case .compact:
            return "compact"
        case .regular:
            return "regular"
        case .none:
            return "none"
        @unknown default:
            return "unknown"
        }
    }
}

private struct Stage33EnvironmentSnapshotRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.monospaced())
        }
    }
}

private struct Stage33AdaptiveCard: View {
    let title: String
    let detail: String
    let accent: Color

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? 10 : 6) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(dynamicTypeSize.isAccessibilitySize ? 16 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(accent.opacity(isPressed ? 0.3 : 0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accent.opacity(0.5), lineWidth: 1)
        )
        .scaleEffect(isPressed ? 0.98 : 1)
        .onLongPressGesture(minimumDuration: 0.15, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

private extension String {
    func localized(locale _: Locale) -> String {
        NSLocalizedString(self, comment: "")
    }
}

#Preview("Stage 33 - Default") {
    Stage33EnvironmentDependentUIView()
}

#Preview("Stage 33 - Accessibility + Dark") {
    Stage33EnvironmentDependentUIView()
        .environment(\.dynamicTypeSize, .large)
        .environment(\.colorScheme, .dark)
        .environment(\.locale, Locale(identifier: "it"))
}
