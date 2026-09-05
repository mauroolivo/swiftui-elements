import SwiftUI

@MainActor
struct Stage7ApplicationWideStateView: View {
    @Environment(AppUIState.self) private var appUIState
    @Environment(Session.self) private var session

    var body: some View {
        @Bindable var appUIState = appUIState

        VStack(alignment: .leading, spacing: 12) {
            Text("Stage 7 - Application-wide state")
                .font(.title3.bold())

            Text("Session: \(session.profile?.displayName ?? "signed out")")
            Text("Selected tab: \(appUIState.selectedTab.rawValue)")
            Text("Catalog path: \(appUIState.catalogPath.count)")

            Picker("Tab", selection: $appUIState.selectedTab) {
                ForEach(AppTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button("Sign out") {
                    session.signOut()
                    appUIState.resetForLogout()
                }
                Button("Sign in sample") { session.signInSampleUser() }
            }

            Text("App-wide state is small and explicit; feature-local state remains outside app scope.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .stageCard()
    }
}

#Preview("Stage 7") {
    Stage7ApplicationWideStateView()
        .environment(AppUIState())
        .environment(Session())
}
