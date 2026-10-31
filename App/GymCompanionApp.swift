import Domain
import SwiftUI
import ViewModels

@main
struct GymCompanionApp: App {
    private let root = CompositionRoot()
    @Environment(\.scenePhase) private var scenePhase

    private var lifecycle: AppLifecycle { AppLifecycle(app: root.model, sync: root.sync, today: root.today) }

    /// Lo que termina el reloj se escucha desde que arranca la app, no desde la pantalla: el reloj
    /// puede despertarla en segundo plano, sin escena.
    init() {
        let lifecycle = lifecycle
        let finished = root.finishedOnWatch()
        Task {
            for await day in finished {
                await lifecycle.workoutFinishedOnWatch(on: day)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(root: root)
                .dismissesKeyboardOnTapOutside()
                .task { await lifecycle.launch() }
                .task { await root.sync.observe() }
                .task {
                    for await _ in root.reconnections() {
                        await lifecycle.reconnected()
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: Task { await lifecycle.becameActive() }
            case .background: Task { await lifecycle.wentToBackground() }
            default: break
            }
        }
    }
}
