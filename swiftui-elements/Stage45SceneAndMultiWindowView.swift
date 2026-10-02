import Observation
import SwiftUI

@MainActor
@Observable
final class Stage45SceneModel {
    let sceneID = UUID()
    var localCounter = 0
    var selectedItemID: CatalogItem.ID? = CatalogItem.samples.first?.id
    var draftMessage = "This note belongs to one window scene."

    init() {
        LabLog.event("Stage45SceneModel init \(sceneID)")
    }

    deinit {
        LabLog.event("Stage45SceneModel deinit \(sceneID)")
    }

    func reset() {
        localCounter = 0
        selectedItemID = CatalogItem.samples.first?.id
        draftMessage = "This note belongs to one window scene."
        LabLog.event("Stage45SceneModel reset \(sceneID)")
    }
}

@MainActor
struct Stage45SceneAndMultiWindowView: View {
    @State private var sceneModel = Stage45SceneModel()
    @SceneStorage("stage45.windowNickname") private var windowNickname = "Untitled window"
    @SceneStorage("stage45.sceneStorageCounter") private var sceneStorageCounter = 0

    @Environment(Session.self) private var session
    @Environment(\.scenePhase) private var scenePhase

    @State private var isInspectorExpanded = true

    var body: some View {
        @Bindable var sceneModel = sceneModel

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stage 45 — Scene and multi-window architecture")
                        .font(.title2.bold())

                    Text("Each window should own its own scene-local UI state. App-global services stay shared.")
                        .foregroundStyle(.secondary)

                    Text("Scene ID: \(sceneModel.sceneID.uuidString)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    Text("Scene phase: \(scenePhaseLabel)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    Text("Open another window from the system UI to compare scene IDs, counters, and SceneStorage values.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .stageCard()

                DisclosureGroup("What lives where?", isExpanded: $isInspectorExpanded) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("• `@State` sceneModel: one model instance per window scene.")
                        Text("• `@SceneStorage` nickname/counter: restored separately for each scene.")
                        Text("• `Session`: app-global, shared by every window.")
                        Text("• This disclosure's expansion state is pure view-local state.")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .stageCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Scene-owned model")
                        .font(.headline)

                    TextField("Window nickname", text: $windowNickname)
                        .textFieldStyle(.roundedBorder)

                    Stepper("Scene counter: \(sceneModel.localCounter)", value: $sceneModel.localCounter)

                    Picker("Focused item", selection: $sceneModel.selectedItemID) {
                        ForEach(CatalogItem.samples) { item in
                            Text(item.title).tag(Optional(item.id))
                        }
                    }

                    Text("Draft note")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    TextEditor(text: $sceneModel.draftMessage)
                        .frame(minHeight: 80)
                        .padding(4)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))

                    Button("Reset this window only") {
                        sceneModel.reset()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .stageCard()

                VStack(alignment: .leading, spacing: 8) {
                    Text("SceneStorage")
                        .font(.headline)

                    Text("Nickname: \(windowNickname)")
                    Text("Per-scene storage counter: \(sceneStorageCounter)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("Bump SceneStorage counter") {
                            sceneStorageCounter += 1
                        }

                        Button("Reset SceneStorage values") {
                            windowNickname = "Untitled window"
                            sceneStorageCounter = 0
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .stageCard()

                VStack(alignment: .leading, spacing: 8) {
                    Text("App-global session")
                        .font(.headline)

                    Text("Resolved session: \(session.profile?.displayName ?? "signed out")")

                    Text("If you sign in or out here, every window sees the same session change because the model is app-global.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("Sign out this session") {
                            session.signOut()
                        }

                        Button("Sign in sample") {
                            session.signInSampleUser()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .stageCard()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Takeaway")
                        .font(.headline)

                    Text("App scope: services and session. Scene scope: each window's route and window-local state. View scope: transient presentation details like expansion flags.")
                    Text("If you put scene-specific UI state in a single app-wide object, independent windows will fight over it.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .stageCard()
            }
            .padding()
        }
        .onAppear {
            LabLog.event("Stage45SceneAndMultiWindowView onAppear scene=\(sceneModel.sceneID)")
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            LabLog.event("Stage45 scenePhase changed: \(oldPhase) → \(newPhase) for \(sceneModel.sceneID)")
        }
    }

    private var scenePhaseLabel: String {
        switch scenePhase {
        case .active:
            return "active"
        case .inactive:
            return "inactive"
        case .background:
            return "background"
        @unknown default:
            return "unknown"
        }
    }
}
