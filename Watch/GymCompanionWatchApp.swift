import SwiftUI

@main
struct GymCompanionWatchApp: App {
    private let root = WatchCompositionRoot()

    var body: some Scene {
        WindowGroup {
            WatchRootView(model: root.model)
                .task { await root.listen() }
        }
    }
}
