import SwiftUI
import UIKit
import ViewModels

@main
struct GymCompanionApp: App {
    private let root = CompositionRoot()
    @State private var model: AppModel?
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(version: root.appVersion)
                .task {
                    let model = await root.makeModel()
                    self.model = model
                    await model.start()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            guard let model else { return }
            switch phase {
            case .background: uploadBeforeSuspension(model)
            case .active: Task { await model.didBecomeActive() }
            default: break
            }
        }
    }

    /// Al pasar a segundo plano se sube lo pendiente; iOS da unos segundos para terminarlo si se
    /// le pide una tarea en segundo plano (el `keepalive` de la PWA).
    private func uploadBeforeSuspension(_ model: AppModel) {
        let background = BackgroundTask(name: "Subir a GitHub")
        Task {
            await model.didEnterBackground()
            background.end()
        }
    }
}

/// Una tarea en segundo plano de iOS, que se termina una sola vez (al acabar o si se agota el tiempo).
@MainActor
private final class BackgroundTask {
    private var identifier = UIBackgroundTaskIdentifier.invalid

    init(name: String) {
        identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            MainActor.assumeIsolated { self?.end() }
        }
    }

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
