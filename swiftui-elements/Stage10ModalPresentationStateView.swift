import SwiftUI

@Observable
private final class Stage10PresentationState {
    var presentedSheet: Stage10SheetRoute?
    var presentedFullScreenCover: Stage10FullScreenCoverRoute?
    var presentedPopover: Stage10PopoverRoute?
    var presentedAlert: Stage10AlertRoute?
    var presentedConfirmationDialog: Stage10ConfirmationDialogRoute?

    var draftTitle = ""
    var sendDiagnostics = true
    var favoriteIDs: Set<CatalogItem.ID> = ["identity"]

    init() {
        LabLog.event("Stage10PresentationState init")
    }

    deinit {
        LabLog.event("Stage10PresentationState deinit")
    }

    func edit(_ item: CatalogItem, source: String) {
        draftTitle = item.title
        presentedSheet = .editor(item.id)
        LabLog.event("Stage10PresentationState presented editor sheet for \(item.id) from \(source)")
    }

    func toggleFavorite(_ itemID: CatalogItem.ID) {
        if favoriteIDs.contains(itemID) {
            favoriteIDs.remove(itemID)
        } else {
            favoriteIDs.insert(itemID)
        }

        LabLog.event("Stage10PresentationState toggled favorite for \(itemID)")
    }

    func clearPresentations() {
        presentedSheet = nil
        presentedFullScreenCover = nil
        presentedPopover = nil
        presentedAlert = nil
        presentedConfirmationDialog = nil
        LabLog.event("Stage10PresentationState cleared presentation state")
    }
}

private enum Stage10SheetRoute: Identifiable, Hashable {
    case settings
    case editor(CatalogItem.ID)

    var id: String {
        switch self {
        case .settings:
            "settings"
        case .editor(let itemID):
            "editor-\(itemID)"
        }
    }

    var label: String {
        switch self {
        case .settings:
            "Settings"
        case .editor(let itemID):
            "Editor: \(itemID)"
        }
    }
}

private enum Stage10FullScreenCoverRoute: Identifiable, Hashable {
    case onboarding

    var id: String {
        switch self {
        case .onboarding:
            "onboarding"
        }
    }

    var label: String {
        switch self {
        case .onboarding:
            "Onboarding"
        }
    }
}

private enum Stage10PopoverRoute: Identifiable, Hashable {
    case inventory
    case itemInfo(CatalogItem.ID)

    var id: String {
        switch self {
        case .inventory:
            "inventory"
        case .itemInfo(let itemID):
            "item-info-\(itemID)"
        }
    }

    var label: String {
        switch self {
        case .inventory:
            "Presentation inventory"
        case .itemInfo(let itemID):
            "Item info: \(itemID)"
        }
    }
}

private enum Stage10AlertRoute: Identifiable, Hashable {
    case discardDraft(CatalogItem.ID)
    case signOutWarning

    var id: String {
        switch self {
        case .discardDraft(let itemID):
            "discard-draft-\(itemID)"
        case .signOutWarning:
            "sign-out-warning"
        }
    }

    var label: String {
        switch self {
        case .discardDraft(let itemID):
            "Discard draft: \(itemID)"
        case .signOutWarning:
            "Sign out warning"
        }
    }
}

private enum Stage10ConfirmationDialogRoute: Identifiable, Hashable {
    case itemActions(CatalogItem.ID)
    case resetPresentationState

    var id: String {
        switch self {
        case .itemActions(let itemID):
            "item-actions-\(itemID)"
        case .resetPresentationState:
            "reset-presentation-state"
        }
    }

    var label: String {
        switch self {
        case .itemActions(let itemID):
            "Actions: \(itemID)"
        case .resetPresentationState:
            "Reset presentation state"
        }
    }
}

struct Stage10ModalPresentationStateView: View {
    @State private var presentationState = Stage10PresentationState()

    init() {
        LabLog.event("Stage10ModalPresentationStateView init")
    }

    var body: some View {
        let _ = LabLog.event("Stage10ModalPresentationStateView body")
        @Bindable var presentationState = presentationState

        NavigationStack {
            List {
                Section("Concept") {
                    Text("Stage 10: Modal presentation as state")
                        .font(.title2.bold())

                    Text("Sheets, covers, popovers, alerts, and confirmation dialogs are all UI presentation state. Instead of many unrelated booleans, this lab models each presentation surface with typed optional routes.")
                        .foregroundStyle(.secondary)
                }

                Section("Avoid boolean piles") {
                    Text("Instead of showSettings, showEditor, showOnboarding, showDeleteAlert, and showActionDialog, use explicit route values like .settings or .editor(itemID).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Stage10PresentationInventory(state: presentationState)

                Section(".sheet(item:)") {
                    Button("Open settings sheet") {
                        presentationState.presentedSheet = .settings
                        LabLog.event("Stage10 requested settings sheet")
                    }

                    ForEach(CatalogItem.samples) { item in
                        Button("Edit \(item.title)") {
                            presentationState.edit(item, source: "root list")
                        }
                    }
                }

                Section(".fullScreenCover(item:)") {
                    Button("Show onboarding cover") {
                        presentationState.presentedFullScreenCover = .onboarding
                        LabLog.event("Stage10 requested onboarding fullScreenCover")
                    }

                    Text("Use full-screen presentation for immersive or required flows. It is still state, not an imperative command.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section(".popover(item:)") {
                    Button("Show presentation inventory popover") {
                        presentationState.presentedPopover = .inventory
                        LabLog.event("Stage10 requested inventory popover")
                    }

                    if let firstItem = CatalogItem.samples.first {
                        Button("Show item info popover") {
                            presentationState.presentedPopover = .itemInfo(firstItem.id)
                            LabLog.event("Stage10 requested item info popover")
                        }
                    }
                }

                Section(".alert and .confirmationDialog") {
                    Button("Ask before discarding draft") {
                        presentationState.presentedAlert = .discardDraft(CatalogItem.samples[0].id)
                        LabLog.event("Stage10 requested discard alert")
                    }

                    Button("Show item action dialog") {
                        presentationState.presentedConfirmationDialog = .itemActions(CatalogItem.samples[0].id)
                        LabLog.event("Stage10 requested item action confirmation dialog")
                    }

                    Button("Show reset dialog") {
                        presentationState.presentedConfirmationDialog = .resetPresentationState
                        LabLog.event("Stage10 requested reset confirmation dialog")
                    }
                }

                Section("Separate concerns") {
                    Stage10StateBoundaryRow(name: "Navigation state", value: "NavigationStack paths and selected tabs")
                    Stage10StateBoundaryRow(name: "Presentation state", value: "Which sheet, cover, popover, alert, or dialog is active")
                    Stage10StateBoundaryRow(name: "Domain state", value: "Catalog items, favorites, profile, saved data")

                    Text("The draft title and favorite IDs are feature/domain state. The optional route enums only answer what is currently being presented.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Stage 10")
            .toolbar {
                Button("Clear") {
                    presentationState.clearPresentations()
                }
            }
        }
        .sheet(item: $presentationState.presentedSheet) { route in
            Stage10SheetDestination(route: route, state: presentationState)
        }
        .fullScreenCover(item: $presentationState.presentedFullScreenCover) { route in
            Stage10FullScreenCoverDestination(route: route)
        }
        .popover(item: $presentationState.presentedPopover) { route in
            Stage10PopoverDestination(route: route, state: presentationState)
                .presentationCompactAdaptation(.popover)
        }
        .alert(
            "Presentation alert",
            isPresented: Binding(
                get: { presentationState.presentedAlert != nil },
                set: { isPresented in
                    if !isPresented {
                        presentationState.presentedAlert = nil
                    }
                }
            ),
            presenting: presentationState.presentedAlert
        ) { route in
            switch route {
            case .discardDraft:
                Button("Discard", role: .destructive) {
                    presentationState.draftTitle = ""
                    presentationState.presentedAlert = nil
                    LabLog.event("Stage10 discarded draft from alert")
                }
                Button("Cancel", role: .cancel) {
                    presentationState.presentedAlert = nil
                }
            case .signOutWarning:
                Button("Continue", role: .destructive) {
                    presentationState.clearPresentations()
                    LabLog.event("Stage10 accepted sign-out warning")
                }
                Button("Cancel", role: .cancel) {
                    presentationState.presentedAlert = nil
                }
            }
        } message: { route in
            switch route {
            case .discardDraft(let itemID):
                Text("Discard the local draft for \(itemID)? This alert is presentation state; the draft text is feature state.")
            case .signOutWarning:
                Text("Sign out would clear presentation state and any user-scoped drafts by explicit policy.")
            }
        }
        .confirmationDialog(
            "Choose an action",
            isPresented: Binding(
                get: { presentationState.presentedConfirmationDialog != nil },
                set: { isPresented in
                    if !isPresented {
                        presentationState.presentedConfirmationDialog = nil
                    }
                }
            ),
            presenting: presentationState.presentedConfirmationDialog
        ) { route in
            switch route {
            case .itemActions(let itemID):
                Button("Edit in sheet") {
                    if let item = CatalogItem.samples.first(where: { $0.id == itemID }) {
                        presentationState.edit(item, source: "confirmation dialog")
                    }
                    presentationState.presentedConfirmationDialog = nil
                }

                Button("Toggle favorite") {
                    presentationState.toggleFavorite(itemID)
                    presentationState.presentedConfirmationDialog = nil
                }

                Button("Cancel", role: .cancel) {
                    presentationState.presentedConfirmationDialog = nil
                }
            case .resetPresentationState:
                Button("Reset presentations", role: .destructive) {
                    presentationState.clearPresentations()
                }

                Button("Cancel", role: .cancel) {
                    presentationState.presentedConfirmationDialog = nil
                }
            }
        } message: { route in
            Text("Active route: \(route.label)")
        }
        .onAppear {
            LabLog.event("Stage10ModalPresentationStateView onAppear")
        }
        .onDisappear {
            LabLog.event("Stage10ModalPresentationStateView onDisappear")
        }
    }
}

private struct Stage10PresentationInventory: View {
    let state: Stage10PresentationState

    var body: some View {
        Section("Presentation state") {
            LabeledContent("Sheet", value: state.presentedSheet?.label ?? "none")
            LabeledContent("Full-screen cover", value: state.presentedFullScreenCover?.label ?? "none")
            LabeledContent("Popover", value: state.presentedPopover?.label ?? "none")
            LabeledContent("Alert", value: state.presentedAlert?.label ?? "none")
            LabeledContent("Confirmation dialog", value: state.presentedConfirmationDialog?.label ?? "none")
            LabeledContent("Draft title", value: state.draftTitle.isEmpty ? "empty" : state.draftTitle)
            LabeledContent("Favorites", value: "\(state.favoriteIDs.count)")
        }
    }
}

private struct Stage10StateBoundaryRow: View {
    let name: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.headline)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct Stage10SheetDestination: View {
    let route: Stage10SheetRoute
    let state: Stage10PresentationState

    var body: some View {
        switch route {
        case .settings:
            Stage10SettingsSheet(state: state)
        case .editor(let itemID):
            Stage10EditorSheet(itemID: itemID, state: state)
        }
    }
}

private struct Stage10SettingsSheet: View {
    let state: Stage10PresentationState

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var state = state

        NavigationStack {
            Form {
                Section("Settings sheet") {
                    Toggle("Send diagnostics", isOn: $state.sendDiagnostics)

                    Text("The active sheet route is presentation state. This diagnostics toggle is settings/domain state owned by the feature model.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Nested owner") {
                    Text("This sheet has no nested presentation. Compare it with the editor sheet, where the editor owns its own help sheet locally.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

private enum Stage10EditorNestedSheetRoute: Identifiable, Hashable {
    case formattingHelp

    var id: String { "formatting-help" }
}

private struct Stage10EditorSheet: View {
    let itemID: CatalogItem.ID
    let state: Stage10PresentationState

    @Environment(\.dismiss) private var dismiss
    @State private var nestedSheet: Stage10EditorNestedSheetRoute?

    private var item: CatalogItem? {
        CatalogItem.samples.first { $0.id == itemID }
    }

    var body: some View {
        @Bindable var state = state

        NavigationStack {
            Form {
                Section("Editor sheet") {
                    LabeledContent("Route item ID", value: itemID)
                    TextField("Draft title", text: $state.draftTitle)
                        .textFieldStyle(.roundedBorder)

                    Text("The sheet route identifies what is presented. The draft title is editable feature state, so it should not be encoded into the sheet route.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Nested presentation") {
                    Button("Open local formatting help sheet") {
                        nestedSheet = .formattingHelp
                        LabLog.event("Stage10 editor opened nested formatting help sheet")
                    }

                    Button("Ask shell alert to discard draft") {
                        state.presentedAlert = .discardDraft(itemID)
                        LabLog.event("Stage10 editor requested shell-owned discard alert")
                    }

                    Text("The nested help sheet is owned by this editor because only the editor cares about it. The discard alert is shell-owned because it can be requested from multiple places.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let item {
                    Section("Original item") {
                        Text(item.title)
                            .font(.headline)
                        Text(item.subtitle)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit item")
            .toolbar {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .sheet(item: $nestedSheet) { route in
            switch route {
            case .formattingHelp:
                Stage10FormattingHelpSheet()
            }
        }
    }
}

private struct Stage10FormattingHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Local nested presentation") {
                    Text("This help sheet is not in Stage10PresentationState because it belongs only to the editor sheet. Keeping it local preserves ownership boundaries.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Formatting help")
            .toolbar {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

private struct Stage10FullScreenCoverDestination: View {
    let route: Stage10FullScreenCoverRoute

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        switch route {
        case .onboarding:
            NavigationStack {
                VStack(spacing: 20) {
                    Image(systemName: "rectangle.portrait.on.rectangle.portrait.angled")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)

                    Text("Full-screen cover")
                        .font(.largeTitle.bold())

                    Text("A full-screen cover is still driven by an optional route. Dismissing it sets the route back to nil through the binding SwiftUI manages.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    Button("Continue") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .navigationTitle("Onboarding")
            }
        }
    }
}

private struct Stage10PopoverDestination: View {
    let route: Stage10PopoverRoute
    let state: Stage10PresentationState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch route {
            case .inventory:
                Text("Presentation inventory")
                    .font(.headline)
                Text("Sheet: \(state.presentedSheet?.label ?? "none")")
                Text("Cover: \(state.presentedFullScreenCover?.label ?? "none")")
                Text("Alert: \(state.presentedAlert?.label ?? "none")")
            case .itemInfo(let itemID):
                Text("Item info")
                    .font(.headline)
                Text(itemID)
                    .font(.body.monospaced())
                Text(CatalogItem.samples.first { $0.id == itemID }?.subtitle ?? "Missing item")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding()
        .frame(maxWidth: 320, alignment: .leading)
    }
}

#Preview("Stage 10 modal presentation as state") {
    Stage10ModalPresentationStateView()
}
