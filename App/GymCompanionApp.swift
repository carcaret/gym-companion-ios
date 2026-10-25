import SwiftUI

@main
struct GymCompanionApp: App {
    private let root = CompositionRoot()

    var body: some Scene {
        WindowGroup {
            ContentView(version: root.appVersion)
        }
    }
}
