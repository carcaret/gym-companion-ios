import SwiftUI

@main
struct GymCompanionApp: App {
    private let root = CompositionRoot()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(root: root)
                .dismissesKeyboardOnTapOutside()
                .task {
                    await root.model.start()
                    await root.sync.synchronize()
                }
                .task { await root.sync.observe() }
                .task {
                    for await _ in root.reconnections() {
                        await root.sync.synchronize()
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            // Al volver a la app, lo que haría la PWA al recargar: subir lo pendiente o bajar
            // lo que se haya cambiado en GitHub. Y poner el reloj al día (puede ser otro día).
            case .active where root.model.data != nil:
                root.model.refreshWatch()
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
