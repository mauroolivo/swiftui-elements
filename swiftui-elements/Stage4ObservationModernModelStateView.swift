import SwiftUI

@Observable
final class Stage4FavoritesModel {
    var favoriteCount = 1
    var query = ""
}

@MainActor
struct Stage4ObservationModernModelStateView: View {
    @State private var model = Stage4FavoritesModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stage 4 - Observation")
                .font(.title3.bold())

            Stage4CountReader(model: model)
            Stage4QueryEditor(model: model)

            Text("Only views that read a property are invalidated by that property.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .stageCard()
    }
}

private struct Stage4CountReader: View {
    let model: Stage4FavoritesModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Count reader").font(.headline)
            Text("Favorites: \(model.favoriteCount)")
            Button("Increment favorites") { model.favoriteCount += 1 }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct Stage4QueryEditor: View {
    let model: Stage4FavoritesModel

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 8) {
            Text("Query editor").font(.headline)
            TextField("Search", text: $model.query)
                .textFieldStyle(.roundedBorder)
            Text("Query: \(model.query.isEmpty ? "(empty)" : model.query)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview("Stage 4") {
    Stage4ObservationModernModelStateView()
}
