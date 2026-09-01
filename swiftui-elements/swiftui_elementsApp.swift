//

import SwiftUI

@main
struct swiftui_elementsApp: App {
    private let itemRepository: any ItemRepository = LiveItemRepository()

    init() {
        LabLog.event("swiftui_elementsApp init")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.itemRepository, itemRepository)
        }
    }
}
