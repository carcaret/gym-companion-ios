import SwiftUI
import WatchKit

@main
struct GymCompanionWatchApp: App {
    @WKApplicationDelegateAdaptor private var delegate: WatchAppDelegate

    var body: some Scene {
        WindowGroup {
            WatchRootView(model: delegate.root.model)
                .task { await delegate.root.listen() }
        }
    }
}
