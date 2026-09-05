import SwiftUI

@MainActor
struct Stage5StateModelServiceView: View {
    @State private var selectedTab = AppTab.catalog
    @State private var searchText = ""
    @State private var serviceName = "LiveItemRepository"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stage 5 - State vs model vs service")
                .font(.title3.bold())

            Picker("Tab", selection: $selectedTab) {
                ForEach(AppTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            TextField("Search query (feature UI state)", text: $searchText)
                .textFieldStyle(.roundedBorder)

            Text("Service dependency: \(serviceName)")
                .font(.caption)

            Text("Rule: do not merge UI state, feature state, domain state, and service dependencies into one giant observable object.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .stageCard()
    }
}

#Preview("Stage 5") {
    Stage5StateModelServiceView()
}
