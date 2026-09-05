import SwiftUI

@MainActor
struct StagePickerView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Foundations") {
                    NavigationLink("Stage 1 - Rendering model") { Stage1RenderingModelView() }
                    NavigationLink("Stage 2 - Identity and lifetime") { Stage2IdentityAndLifetimeView() }
                    NavigationLink("Stage 3 - Local state ownership") { Stage3LocalStateOwnershipView() }
                    NavigationLink("Stage 4 - Observation") { Stage4ObservationModernModelStateView() }
                }

                Section("Architecture") {
                    NavigationLink("Stage 5 - State vs model vs service") { Stage5StateModelServiceView() }
                    NavigationLink("Stage 6 - Environment and DI") { Stage6EnvironmentDependencyInjectionView() }
                    NavigationLink("Stage 7 - Application-wide state") { Stage7ApplicationWideStateView() }
                    NavigationLink("Stage 8 - NavigationStack fundamentals") { Stage8NavigationStackFundamentalsView() }
                }

                Section("Advanced") {
                    NavigationLink("Stage 9 - Navigation architecture") { Stage9NavigationArchitectureView() }
                    NavigationLink("Stage 10 - Modal state") { Stage10ModalPresentationStateView() }
                    NavigationLink("Stage 11 - Deep linking") { Stage11DeepLinkingView() }
                    NavigationLink("Stage 12 - Navigation restoration") { Stage12NavigationRestorationView() }
                    NavigationLink("Stage 13 - Lists at scale") { Stage13ListProductionScaleView() }
                }
            }
            .navigationTitle("SwiftUI Stages")
        }
    }
}

#Preview("Stage picker") {
    StagePickerView()
        .environment(AppRouter())
        .environment(AppUIState())
        .environment(Session())
        .environment(\.itemRepository, PreviewItemRepository())
}
