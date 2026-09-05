import SwiftUI

private enum Stage8Route: Hashable {
    case item(String)
}

@MainActor
struct Stage8NavigationStackFundamentalsView: View {
    @State private var path: [Stage8Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            List(CatalogItem.samples) { item in
                NavigationLink(value: Stage8Route.item(item.id)) {
                    VStack(alignment: .leading) {
                        Text(item.title).font(.headline)
                        Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Stage 8 - Navigation")
            .navigationDestination(for: Stage8Route.self) { route in
                switch route {
                case .item(let id):
                    Text("Detail for \(id)")
                        .font(.title3)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Push") {
                        if let first = CatalogItem.samples.first {
                            path.append(.item(first.id))
                        }
                    }
                    Button("Pop") {
                        if !path.isEmpty { path.removeLast() }
                    }
                    Button("Reset") { path.removeAll() }
                }
            }
        }
        .stageCard()
    }
}

#Preview("Stage 8") {
    Stage8NavigationStackFundamentalsView()
}
