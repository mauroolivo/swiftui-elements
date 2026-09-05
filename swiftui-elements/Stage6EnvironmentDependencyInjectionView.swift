import SwiftUI

@MainActor
struct Stage6EnvironmentDependencyInjectionView: View {
    @Environment(\.itemRepository) private var itemRepository
    @State private var result = "Not loaded"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stage 6 - Environment and DI")
                .font(.title3.bold())

            Text("Resolved repository:")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(itemRepository.diagnosticName)
                .font(.caption.monospaced())

            Button("Fetch featured items") {
                let repository = itemRepository
                Task {
                    do {
                        let items = try await repository.featuredItems()
                        result = "Loaded \(items.count): \(items.map(\.title).joined(separator: ", "))"
                    } catch {
                        result = "Failed: \(error.localizedDescription)"
                    }
                }
            }

            Text(result)
                .font(.caption)
        }
        .padding()
        .stageCard()
    }
}

#Preview("Stage 6") {
    Stage6EnvironmentDependencyInjectionView()
        .environment(\.itemRepository, PreviewItemRepository())
}
