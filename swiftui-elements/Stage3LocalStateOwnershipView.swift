import SwiftUI

@MainActor
struct Stage3LocalStateOwnershipView: View {
    @State private var draft = "Identity"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stage 3 - Local state ownership")
                .font(.title3.bold())

            Text("Parent owns the source of truth and projects a binding into the editor.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Stage3Editor(text: $draft)
            Stage3Preview(text: draft)
        }
        .padding()
        .stageCard()
    }
}

private struct Stage3Editor: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Editor").font(.headline)
            TextField("Title", text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

private struct Stage3Preview: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Preview").font(.headline)
            Text(text.isEmpty ? "(empty)" : text)
                .font(.title3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview("Stage 3") {
    Stage3LocalStateOwnershipView()
}
