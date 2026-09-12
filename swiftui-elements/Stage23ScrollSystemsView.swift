import SwiftUI

@MainActor
struct Stage23ScrollSystemsView: View {
    @State private var activeExercise: Exercise = .programmaticPosition

    enum Exercise: String, CaseIterable, Identifiable {
        case programmaticPosition = "Jump To Item"
        case restoration = "Restore Position"
        case paging = "Paging"
        case stickyHeader = "Sticky Header"

        var id: Self { self }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stage 23 - Scroll Systems")
                .font(.title3.bold())

            Text("This stage treats scrolling as explicit state: position IDs, paging targets, and pinned/animated headers.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Exercise", selection: $activeExercise) {
                ForEach(Exercise.allCases) { exercise in
                    Text(exercise.rawValue).tag(exercise)
                }
            }
            .pickerStyle(.segmented)

            switch activeExercise {
            case .programmaticPosition:
                Stage23ProgrammaticPositionExercise()
            case .restoration:
                Stage23RestorationExercise()
            case .paging:
                Stage23PagingExercise()
            case .stickyHeader:
                Stage23StickyHeaderExercise()
            }
        }
        .padding()
    }
}

private struct Stage23ProgrammaticPositionExercise: View {
    @State private var scrollPositionID: ScrollLesson.ID? = ScrollLesson.samples[0].id
    private let lessons = ScrollLesson.samples
    @State var index: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Concept")
                .font(.headline)

            Text("`scrollPosition(id:)` lets state own where the scroll view should land. You jump by changing state, not by imperative view mutation.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Prediction")
                .font(.subheadline.bold())

            Text("Tap \"Jump to Last\". Which row should become centered, and what value should `scrollPositionID` show after the animation?")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("GO") {
                    withAnimation(.snappy) {
                        index += 1
                        scrollPositionID = lessons[index].id
                    }
                }
                .buttonStyle(.bordered)
                Button("Jump to First") {
                    withAnimation(.snappy) {
                        scrollPositionID = lessons.first?.id
                    }
                }
                .buttonStyle(.bordered)

                Button("Jump to Last") {
                    withAnimation(.snappy) {
                        scrollPositionID = lessons.last?.id
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(lessons) { lesson in
                        Stage23LessonRow(lesson: lesson)
                            .id(lesson.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 4)
            }
            .frame(height: 290)
            .scrollPosition(id: $scrollPositionID, anchor: .top)
            .scrollTargetBehavior(.viewAligned)

            Text("Current scroll state: \(scrollPositionID ?? "nil")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct Stage23RestorationExercise: View {
    @State private var isFeedMounted = true
    @State private var keepRestoredPosition = true
    @State private var rememberedPositionID: ScrollLesson.ID? = ScrollLesson.samples[8].id

    private let lessons = ScrollLesson.samples

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Concept")
                .font(.headline)

            Text("Position is restorable only if a longer-lived owner keeps the scroll ID alive while the scroll view goes away.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Preserve remembered position across unmount", isOn: $keepRestoredPosition)

            HStack {
                Button(isFeedMounted ? "Unmount Feed" : "Remount Feed") {
                    if isFeedMounted == true, keepRestoredPosition == false {
                        rememberedPositionID = nil
                    }

                    withAnimation(.easeInOut(duration: 0.25)) {
                        isFeedMounted.toggle()
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Clear remembered position") {
                    rememberedPositionID = nil
                }
                .buttonStyle(.bordered)
            }

            if isFeedMounted {
                Stage23RestorableFeed(
                    lessons: lessons,
                    initialRestorationID: rememberedPositionID,
                    rememberedPositionID: $rememberedPositionID
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                Text("Feed removed from hierarchy. The only restoration input is `rememberedPositionID = \(rememberedPositionID ?? "nil")`.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
                    .padding()
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                    .transition(.opacity)
            }
        }
        .stageCard()
    }
}

private struct Stage23RestorableFeed: View {
    let lessons: [ScrollLesson]
    let initialRestorationID: ScrollLesson.ID?
    @Binding var rememberedPositionID: ScrollLesson.ID?

    @State private var livePositionID: ScrollLesson.ID?
    @State private var isHydratingFromRememberedState = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Run")
                .font(.subheadline.bold())

            Text("1) Scroll near the bottom. 2) Unmount and remount feed. 3) Repeat with preservation ON then OFF.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(lessons) { lesson in
                        Stage23LessonRow(lesson: lesson)
                            .id(lesson.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 4)
            }
            .frame(height: 250)
            .scrollPosition(id: $livePositionID, anchor: .center)
            .scrollTargetBehavior(.viewAligned)
            .onAppear {
                // Restore first, then allow live scroll updates to write back.
                isHydratingFromRememberedState = true
                livePositionID = initialRestorationID

                Task {
                    try? await Task.sleep(for: .milliseconds(250))
                    isHydratingFromRememberedState = false
                }
            }
            .onChange(of: livePositionID) { _, newValue in
                guard isHydratingFromRememberedState == false else { return }
                rememberedPositionID = newValue
            }

            Text("Remembered ID in parent state: \(rememberedPositionID ?? "nil")")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Live ID in mounted feed: \(livePositionID ?? "nil")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct Stage23PagingExercise: View {
    @State private var currentPageID: Int? = 0

    private let pages = PagingCard.samples

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Concept")
                .font(.headline)

            Text("Paging also becomes state when each page has a stable ID. `scrollTargetBehavior(.paging)` aligns movement to those IDs.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Previous") {
                    guard let currentPageID else { return }
                    withAnimation(.snappy) {
                        self.currentPageID = max(0, currentPageID - 1)
                    }
                }
                .buttonStyle(.bordered)

                Button("Next") {
                    guard let currentPageID else { return }
                    withAnimation(.snappy) {
                        self.currentPageID = min(pages.count - 1, currentPageID + 1)
                    }
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Text("Page \((currentPageID ?? 0) + 1)/\(pages.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(pages) { page in
                        Stage23PagingCard(page: page)
                            .containerRelativeFrame(.horizontal)
                            .id(page.id)
                    }
                }
                .scrollTargetLayout()
            }
            .frame(height: 220)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentPageID)

            Text("Explanation: the selected page is just an `Int?` in state. That state can be deep-linked, restored, or synchronized with other feature state.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct Stage23StickyHeaderExercise: View {
    @State private var lastVisibleRowID: Int = 1

    private let firstSectionRows = StickySectionRow.make(section: "A", range: 1...14)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Concept")
                .font(.headline)

            Text("Pinned section headers solve sticky behavior without geometry hacks. `scrollTransition` lets rows react to visibility phase.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Last row that reported visibility: #\(lastVisibleRowID)")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(firstSectionRows) { row in
                            Stage23TimelineRow(index: row.index)
                                .id(row.id)
                                .onAppear {
                                    if lastVisibleRowID != row.index {
                                        lastVisibleRowID = row.index
                                    }
                                }
                                .scrollTransition(axis: .vertical) { content, phase in
                                    let distance = min(abs(phase.value), 1)
                                    return content
                                        .opacity(1 - (0.55 * distance))
                                        .scaleEffect(1 - (0.12 * distance))
                                }

                            Divider()
                        }
                    } header: {
                        Stage23PinnedHeader(title: "Section A - Track feed milestones")
                    }
                }
            }
            .frame(height: 280)

            Text("Takeaway: drive scroll effects from state and official scroll APIs. Avoid `DispatchQueue.main.async` as a generic scroll timing fix.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }
}

private struct Stage23LessonRow: View {
    let lesson: ScrollLesson

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(lesson.title)
                .font(.subheadline.bold())
            Text(lesson.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct Stage23PagingCard: View {
    let page: PagingCard

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(page.color.gradient)

            VStack(alignment: .leading, spacing: 8) {
                Text(page.title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text(page.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

private struct Stage23PinnedHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.bold())
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

private struct Stage23TimelineRow: View {
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.blue)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text("Milestone #\(index)")
                    .font(.subheadline.bold())
                Text("Observe transition and visibility while this row moves in and out of focus.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct ScrollLesson: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String

    static let samples: [ScrollLesson] = [
        ScrollLesson(id: "identity", title: "Identity", subtitle: "Use stable row IDs so position state remains meaningful."),
        ScrollLesson(id: "ownership", title: "Ownership", subtitle: "Parent scope should own persisted scroll position."),
        ScrollLesson(id: "projection", title: "Projection", subtitle: "Children can bind to parentowned scroll IDs."),
        ScrollLesson(id: "targetlayout", title: "Scroll Target Layout", subtitle: "Mark targetable children using `scrollTargetLayout()`."),
        ScrollLesson(id: "viewaligned", title: "View Aligned", subtitle: "Use view-aligned behavior when jumping to rows."),
        ScrollLesson(id: "paging", title: "Paging", subtitle: "Paging is target selection plus snap behavior."),
        ScrollLesson(id: "restoration", title: "Restoration", subtitle: "Persist only the state worth restoring."),
        ScrollLesson(id: "deeplink", title: "Deep Link", subtitle: "Route values can set initial scroll target."),
        ScrollLesson(id: "lifetime", title: "Lifetime", subtitle: "Unmounting removes view state but not parent-owned state."),
        ScrollLesson(id: "visibility", title: "Visibility", subtitle: "Use scroll transitions for visibility-aware effects."),
        ScrollLesson(id: "instrumentation", title: "Instrumentation", subtitle: "Profile expensive work, not body evaluation count."),
        ScrollLesson(id: "resilience", title: "Resilience", subtitle: "Handle missing IDs when restoring older state."),
        ScrollLesson(id: "policy", title: "Policy", subtitle: "Reset scroll state explicitly on logout/session changes.")
    ]
}

private struct PagingCard: Identifiable {
    let id: Int
    let title: String
    let description: String
    let color: Color

    static let samples: [PagingCard] = [
        PagingCard(id: 0, title: "Catalog", description: "Page-driven browsing experience.", color: .blue),
        PagingCard(id: 1, title: "Search", description: "Search state can jump directly to a specific page.", color: .purple),
        PagingCard(id: 2, title: "Favorites", description: "Persisted IDs can restore favorite page context.", color: .orange),
        PagingCard(id: 3, title: "Profile", description: "Session transitions may reset restricted pages.", color: .green)
    ]
}

private struct StickySectionRow: Identifiable {
    let id: String
    let index: Int

    static func make(section: String, range: ClosedRange<Int>) -> [StickySectionRow] {
        range.map { value in
            StickySectionRow(id: "\(section)-\(value)", index: value)
        }
    }
}

#Preview {
    Stage23ScrollSystemsView()
}
