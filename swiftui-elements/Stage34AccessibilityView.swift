import SwiftUI

@MainActor
struct Stage34AccessibilityView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    @State private var lessonExpanded = false
    @State private var isDownloaded = false

    var body: some View {
        NavigationStack {
            List {
                Section("Stage 34 - Accessibility") {
                    Text("Concept")
                        .font(.headline)
                    Text("Accessibility is part of the view contract, not a finishing pass. A custom SwiftUI hierarchy is visually rich, but assistive technologies only understand the semantics you expose.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Problem")
                        .font(.headline)
                    Text("A row built from shapes, colors, and tap gestures can look correct while still being ambiguous to VoiceOver, fragile at large Dynamic Type sizes, and hard to operate because the hit target is too small.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Prediction")
                        .font(.headline)
                    Text("Before running: which demo should read as one coherent element, which one will likely expose noisy child elements, and what should change when you enable high contrast, Differentiate Without Color, or Reduce Motion?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Implementation") {
                    Text("Resolved accessibility environment")
                        .font(.headline)

                    Stage34EnvironmentSnapshotRow(label: "Dynamic Type", value: "\(dynamicTypeSize)")
                    Stage34EnvironmentSnapshotRow(label: "Reduce Motion", value: reduceMotion ? "enabled" : "disabled")
                    Stage34EnvironmentSnapshotRow(label: "Color scheme contrast", value: colorSchemeContrast == .increased ? "increased" : "standard")
                    Stage34EnvironmentSnapshotRow(label: "Differentiate Without Color", value: differentiateWithoutColor ? "enabled" : "disabled")

                    Text("These values are runtime inputs. Accessibility is not separate from layout, motion, or styling; it changes how this view should behave.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Semantic summary card") {
                    Stage34LessonSummaryCard(isExpanded: $lessonExpanded)

                    Text("This card intentionally collapses multiple child views into one coherent accessible element using `accessibilityElement(children: .ignore)`, then supplies a custom label, value, and hint.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Custom control refactor") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Broken version")
                            .font(.headline)

                        Stage34InaccessibleDownloadRow(
                            isDownloaded: isDownloaded,
                            differentiateWithoutColor: differentiateWithoutColor,
                            highContrast: colorSchemeContrast == .increased,
                            onTap: toggleDownload
                        )

                        Text("This row uses a plain tap gesture on decorative content. VoiceOver has no native toggle semantics, state is communicated heavily through styling, and the hit target is only as generous as the drawn content happens to be.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .stageCard()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Refactored version")
                            .font(.headline)

                        Stage34AccessibleDownloadControl(
                            isDownloaded: $isDownloaded,
                            reduceMotion: reduceMotion,
                            differentiateWithoutColor: differentiateWithoutColor,
                            highContrast: colorSchemeContrast == .increased
                        )

                        Text("The visual design stays custom, but assistive technologies see a native `Toggle` via `accessibilityRepresentation`. The control also guarantees a larger hit target and adds non-color cues when accessibility settings request them.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .stageCard()
                }

                Section("Run") {
                    Text("1) Turn on VoiceOver in Simulator and swipe through the summary card, the broken row, and the refactored control.")
                    Text("2) Increase Dynamic Type to an accessibility size and confirm the layouts still read cleanly.")
                    Text("3) Enable Differentiate Without Color and Increase Contrast in Accessibility settings.")
                    Text("4) Toggle Reduce Motion, then activate the download control again and compare the behavior.")
                    Text("5) Use the Accessibility Inspector hit-test mode to compare the tap area of both controls.")
                }

                Section("Explanation") {
                    Text("SwiftUI renders views visually, but accessibility requires an additional semantic layer. `accessibilityLabel`, `accessibilityValue`, and `accessibilityHint` describe meaning; `accessibilityElement` defines grouping; `accessibilityRepresentation` can replace a custom subtree with native semantics. Environment-driven accessibility values then influence layout, contrast, and motion just like any other dependency.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Refactor") {
                    Text("When a custom control really behaves like a native control, prefer exposing the native behavior semantically instead of inventing your own accessibility story from scratch. Only keep bespoke semantics when the control is genuinely novel.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Takeaway") {
                    Text("- Accessibility belongs in the initial design of a view, not after the layout is done.")
                    Text("- Group child views into the semantic unit users actually need to navigate.")
                    Text("- If a custom control behaves like a toggle or button, expose that native meaning explicitly.")
                }
            }
            .navigationTitle("Accessibility")
        }
        .onAppear {
            LabLog.event("Stage34AccessibilityView onAppear")
        }
    }

    private func toggleDownload() {
        if reduceMotion {
            isDownloaded.toggle()
        } else {
            withAnimation(.snappy(duration: 0.22)) {
                isDownloaded.toggle()
            }
        }
    }
}

private struct Stage34EnvironmentSnapshotRow: View {
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

private struct Stage34LessonSummaryCard: View {
    @Binding var isExpanded: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let completion = 0.72

    var body: some View {
        Button {
            if reduceMotion {
                isExpanded.toggle()
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? 12 : 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rendering Model")
                            .font(.headline)
                        Text("18 min • Intermediate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("72%")
                        .font(.title3.bold())
                        .monospacedDigit()
                        .foregroundStyle(.blue)
                }

                ProgressView(value: completion)
                    .tint(.blue)

                if isExpanded {
                    Text("Expensive visual structure does not automatically imply expensive underlying UI reconstruction. The semantic summary should still be one concise element for assistive technology.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(dynamicTypeSize.isAccessibilitySize ? 18 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lesson Rendering Model")
        .accessibilityValue("72 percent complete, 18 minutes, intermediate")
        .accessibilityHint(isExpanded ? "Double tap to collapse lesson notes." : "Double tap to expand lesson notes.")
    }
}

private struct Stage34InaccessibleDownloadRow: View {
    let isDownloaded: Bool
    let differentiateWithoutColor: Bool
    let highContrast: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isDownloaded ? Color.green : Color.gray)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text("Offline download")
                    .font(.subheadline.bold())
                Text("Identity lesson")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if differentiateWithoutColor || highContrast {
                Text(isDownloaded ? "ON" : "OFF")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.thinMaterial, in: Capsule())
            }

            Image(systemName: isDownloaded ? "arrow.down.circle.fill" : "arrow.down.circle")
                .foregroundStyle(isDownloaded ? .green : .secondary)
        }
        .padding(.vertical, 6)
        .onTapGesture(perform: onTap)
    }
}

private struct Stage34AccessibleDownloadControl: View {
    @Binding var isDownloaded: Bool

    let reduceMotion: Bool
    let differentiateWithoutColor: Bool
    let highContrast: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var statusText: String {
        isDownloaded ? "Downloaded" : "Not downloaded"
    }

    private var accentColor: Color {
        isDownloaded ? .green : .secondary
    }

    var body: some View {
        Button {
            if reduceMotion {
                isDownloaded.toggle()
            } else {
                withAnimation(.snappy(duration: 0.22)) {
                    isDownloaded.toggle()
                }
            }
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 12) {
                        header
                        statusRow
                    }
                } else {
                    HStack(spacing: 12) {
                        header
                        Spacer(minLength: 12)
                        statusRow
                    }
                }
            }
            .padding(dynamicTypeSize.isAccessibilitySize ? 18 : 14)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(accentColor.opacity(isDownloaded ? 0.18 : 0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(highContrast ? accentColor : accentColor.opacity(0.55), lineWidth: highContrast ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle("Offline download", isOn: $isDownloaded)
                .accessibilityHint("Keeps the Identity lesson available without a network connection.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                .font(.title3)
                .foregroundStyle(accentColor)

            VStack(alignment: .leading, spacing: 3) {
                Text("Offline download")
                    .font(.headline)
                Text("Identity lesson")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusRow: some View {
        Group {
            if differentiateWithoutColor || highContrast {
                Text(statusText)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.background, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(accentColor, lineWidth: highContrast ? 2 : 1)
                    )
            } else {
                Label(statusText, systemImage: isDownloaded ? "checkmark" : "minus")
                    .font(.caption.bold())
                    .foregroundStyle(accentColor)
            }
        }
    }
}

#Preview("Stage 34 - Default") {
    Stage34AccessibilityView()
}

#Preview("Stage 34 - Accessibility Settings") {
    Stage34AccessibilityView()
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
}
