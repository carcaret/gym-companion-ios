import SwiftUI

@main
struct GymCompanionApp: App {
    private let root = CompositionRoot()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(root: root)
                .onAppear { Keyboard.dismissOnTapOutside() }
                .task {
                    await root.model.start()
                    await root.sync.synchronize()
                }
                .task { await root.sync.observe() }
                .task {
                    for await _ in root.reconnections() {
                        await root.sync.synchronize(afterReconnect: true)
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            // Al volver a la app, lo que haría la PWA al recargar: subir lo pendiente o bajar
            // lo que se haya cambiado en GitHub.
            case .active where root.model.data != nil:
                Task { await root.sync.synchronize() }
            // Al irse a segundo plano, lo pendiente de subir sale ya (`beforeunload` en la PWA).
            case .background:
                Task {
                    await root.today.commitTyping()
                    await root.repository.flush()
                }
            default:
                break
            }
        }
    }
}
