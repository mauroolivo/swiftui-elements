//

import SwiftUI

@main
struct swiftui_elementsApp: App {
    @State private var appRouter = AppRouter()
    @State private var appUIState = AppUIState()
    @State private var session = Session()

    private let itemRepository: any ItemRepository = LiveItemRepository()

    init() {
        LabLog.event("swiftui_elementsApp init")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appRouter)
                .environment(appUIState)
                .environment(session)
                .environment(\.itemRepository, itemRepository)
        }
    }
}
