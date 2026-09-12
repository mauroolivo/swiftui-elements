import SwiftUI

@MainActor
struct Stage22TransitionsMatchedGeometryView: View {
    @State private var selectedCardID: CardItem.ID?
    @State private var activeExercise: Exercise = .basicTransition
    @Namespace private var matchedNamespace
    @Namespace private var brokenNamespace

    enum Exercise: String, CaseIterable, Identifiable {
        case basicTransition = "Basic Transition"
        case matchedGeometry = "Matched Geometry"
        case brokenIdentity = "Broken Identity"

        var id: Self { self }
    }

    private let cards = CardItem.samples

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Stage 22 — Transitions and Matched Geometry")
                    .font(.title3.bold())

                Text("This stage compares ordinary insertion/removal transitions with hero-style animations created by `matchedGeometryEffect`.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Exercise", selection: $activeExercise) {
                    ForEach(Exercise.allCases) { exercise in
                        Text(exercise.rawValue).tag(exercise)
                    }
                }
                .pickerStyle(.segmented)

                switch activeExercise {
                case .basicTransition:
                    Stage22BasicTransitionExercise(cards: cards, selectedCardID: $selectedCardID)
                case .matchedGeometry:
                    Stage22MatchedGeometryExercise(cards: cards, selectedCardID: $selectedCardID, namespace: matchedNamespace)
                case .brokenIdentity:
                    Stage22BrokenIdentityExercise(cards: cards, selectedCardID: $selectedCardID, namespace: brokenNamespace)
                }
            }
            .padding()
        }
        .onChange(of: activeExercise) {
            selectedCardID = nil
        }
    }
}

private struct Stage22BasicTransitionExercise: View {
    let cards: [CardItem]
    @Binding var selectedCardID: CardItem.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Concept")
                .font(.headline)

            Text("A transition animates insertion and removal. SwiftUI uses it when state changes cause one branch of the view tree to disappear and another to appear.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            if let selectedCard {
                Stage22DetailCard(card: selectedCard, showsMatchedGeometry: false, namespace: nil) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        selectedCardID = nil
                    }
                }
//                .transition(.move(edge: .bottom).combined(with: .opacity))
                
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .scale(scale: 0.82).combined(with: .opacity)
                    )
                )
                
            } else {
                Text("Prediction")
                    .font(.subheadline.bold())

                Text("Tap a card. The grid should leave as one inserted/removed region, and the detail card should enter from the bottom. There is no hero connection between them yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Stage22CardGrid(cards: cards) { card in
                    Stage22GridCard(card: card, showsMatchedGeometry: false, namespace: nil)
                } onTap: { card in
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        selectedCardID = card.id
                    }
                }
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .stageCard()
    }

    private var selectedCard: CardItem? {
        guard let selectedCardID else { return nil }
        return cards.first(where: { $0.id == selectedCardID })
    }
}

private struct Stage22MatchedGeometryExercise: View {
    let cards: [CardItem]
    @Binding var selectedCardID: CardItem.ID?
    let namespace: Namespace.ID

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Concept")
                .font(.headline)

            Text("`matchedGeometryEffect` does not just fade one view out and another in. It tells SwiftUI that two views in different branches represent the same visual element over time.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            if let selectedCard {
                Stage22DetailCard(card: selectedCard, showsMatchedGeometry: true, namespace: namespace) {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        selectedCardID = nil
                    }
                }
                .transition(.opacity)
            } else {
                Text("Prediction")
                    .font(.subheadline.bold())

                Text("Tap a card. The icon, title, and background should appear to morph from the grid cell into the larger detail card because the source and destination share the same matched-geometry IDs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Stage22CardGrid(cards: cards) { card in
                    Stage22GridCard(card: card, showsMatchedGeometry: true, namespace: namespace)
                } onTap: { card in
                    withAnimation(.easeInOut(duration: 0.35)) {
                        selectedCardID = card.id
                    }
                }
                .transition(.opacity)
            }

            Text("Key idea: matched geometry depends on stable identity. Same namespace + same ID = SwiftUI can connect the views.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var selectedCard: CardItem? {
        guard let selectedCardID else { return nil }
        return cards.first(where: { $0.id == selectedCardID })
    }
}

private struct Stage22BrokenIdentityExercise: View {
    let cards: [CardItem]
    @Binding var selectedCardID: CardItem.ID?
    let namespace: Namespace.ID

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Concept")
                .font(.headline)

            Text("This version is intentionally wrong. It still uses `matchedGeometryEffect`, but the source and destination IDs do not match.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            if let selectedCard {
                Stage22BrokenDetailCard(card: selectedCard, namespace: namespace) {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        selectedCardID = nil
                    }
                }
                .transition(.opacity)
            } else {
                Text("Prediction")
                    .font(.subheadline.bold())

                Text("Tap a card. You should mostly see a fade, not a hero animation. SwiftUI cannot join the views because their matched-geometry IDs intentionally disagree.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Stage22CardGrid(cards: cards) { card in
                    Stage22BrokenGridCard(card: card, namespace: namespace)
                } onTap: { card in
                    withAnimation(.easeInOut(duration: 0.35)) {
                        selectedCardID = card.id
                    }
                }
                .transition(.opacity)
            }

            Text("Broken on purpose: grid IDs are `grid-*`, detail IDs are `detail-*`. Same namespace is not enough; the IDs must also line up.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .stageCard()
    }

    private var selectedCard: CardItem? {
        guard let selectedCardID else { return nil }
        return cards.first(where: { $0.id == selectedCardID })
    }
}

private struct Stage22CardGrid<CardContent: View>: View {
    let cards: [CardItem]
    let content: (CardItem) -> CardContent
    let onTap: (CardItem) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            ForEach(cards) { card in
                Button {
                    onTap(card)
                } label: {
                    content(card)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct Stage22GridCard: View {
    let card: CardItem
    let showsMatchedGeometry: Bool
    let namespace: Namespace.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            icon
            title
            Text(card.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .padding()
        .background(background)
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var icon: some View {
        if let namespace, showsMatchedGeometry {
            Image(systemName: card.icon)
                .font(.title2)
                .matchedGeometryEffect(id: "card-\(card.id)-icon", in: namespace)
        } else {
            Image(systemName: card.icon)
                .font(.title2)
        }
    }

    @ViewBuilder
    private var title: some View {
        if let namespace, showsMatchedGeometry {
            Text(card.title)
                .font(.subheadline.bold())
                .matchedGeometryEffect(id: "card-\(card.id)-title", in: namespace)
        } else {
            Text(card.title)
                .font(.subheadline.bold())
        }
    }

    @ViewBuilder
    private var background: some View {
        if let namespace, showsMatchedGeometry {
            RoundedRectangle(cornerRadius: 12)
                .fill(card.color.opacity(0.22))
                .matchedGeometryEffect(id: "card-\(card.id)-background", in: namespace)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(card.color.opacity(0.22))
        }
    }
}

private struct Stage22DetailCard: View {
    let card: CardItem
    let showsMatchedGeometry: Bool
    let namespace: Namespace.ID?
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            icon
                .frame(maxWidth: .infinity, alignment: .leading)

            title
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(card.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Close", action: onClose)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(background)
    }

    @ViewBuilder
    private var icon: some View {
        if let namespace, showsMatchedGeometry {
            Image(systemName: card.icon)
                .font(.system(size: 48))
                .matchedGeometryEffect(id: "card-\(card.id)-icon", in: namespace)
        } else {
            Image(systemName: card.icon)
                .font(.system(size: 48))
        }
    }

    @ViewBuilder
    private var title: some View {
        if let namespace, showsMatchedGeometry {
            Text(card.title)
                .font(.title2.bold())
                .matchedGeometryEffect(id: "card-\(card.id)-title", in: namespace)
        } else {
            Text(card.title)
                .font(.title2.bold())
        }
    }

    @ViewBuilder
    private var background: some View {
        if let namespace, showsMatchedGeometry {
            RoundedRectangle(cornerRadius: 16)
                .fill(.thinMaterial)
                .matchedGeometryEffect(id: "card-\(card.id)-background", in: namespace)
        } else {
            RoundedRectangle(cornerRadius: 16)
                .fill(.thinMaterial)
        }
    }
}

private struct Stage22BrokenGridCard: View {
    let card: CardItem
    let namespace: Namespace.ID

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: card.icon)
                .font(.title2)
                .matchedGeometryEffect(id: "grid-\(card.id)-icon", in: namespace)

            Text(card.title)
                .font(.subheadline.bold())
                .matchedGeometryEffect(id: "grid-\(card.id)-title", in: namespace)

            Text(card.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(card.color.opacity(0.22))
                .matchedGeometryEffect(id: "grid-\(card.id)-background", in: namespace)
        )
    }
}

private struct Stage22BrokenDetailCard: View {
    let card: CardItem
    let namespace: Namespace.ID
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: card.icon)
                .font(.system(size: 48))
                .matchedGeometryEffect(id: "detail-\(card.id)-icon", in: namespace)

            Text(card.title)
                .font(.title2.bold())
                .matchedGeometryEffect(id: "detail-\(card.id)-title", in: namespace)

            Text(card.description)
                .font(.body)
                .foregroundStyle(.secondary)

            Button("Close", action: onClose)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.thinMaterial)
                .matchedGeometryEffect(id: "detail-\(card.id)-background", in: namespace)
        )
    }
}

private struct CardItem: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: Color

    static let samples: [CardItem] = [
        CardItem(
            id: "transition",
            title: "Insertion",
            description: "A transition describes how a view enters or leaves the hierarchy.",
            icon: "rectangle.and.arrow.up.right.and.arrow.down.left",
            color: .blue
        ),
        CardItem(
            id: "removal",
            title: "Removal",
            description: "Removal animation is separate from the view's steady-state appearance.",
            icon: "rectangle.portrait.and.arrow.right",
            color: .green
        ),
        CardItem(
            id: "hero",
            title: "Matched Geometry",
            description: "Two branches can animate like one visual element when identity is stable.",
            icon: "sparkles.rectangle.stack",
            color: .purple
        ),
        CardItem(
            id: "identity",
            title: "Identity",
            description: "If namespace or IDs do not agree, the hero animation breaks.",
            icon: "person.text.rectangle",
            color: .orange
        )
    ]
}

#Preview {
    Stage22TransitionsMatchedGeometryView()
}
