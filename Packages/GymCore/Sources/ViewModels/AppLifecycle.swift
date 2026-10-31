import Application
import Domain

/// Lo que hace la app al arrancar, al volver a ella, al volver la red y al irse a segundo plano. La
/// `App` de SwiftUI solo lo llama.
@MainActor
public struct AppLifecycle {
    private let app: AppModel
    private let sync: SyncModel
    private let today: TodayModel

    public init(app: AppModel, sync: SyncModel, today: TodayModel) {
        self.app = app
        self.sync = sync
        self.today = today
    }

    /// Carga los datos y sincroniza.
    public func launch() async {
        await app.start()
        await sync.synchronize()
    }

    /// Al volver a la app, lo que haría la PWA al recargar: subir lo pendiente o bajar lo que se
    /// haya cambiado en GitHub. Y poner el reloj al día (puede ser otro día). Sin datos cargados,
    /// nada.
    public func becameActive() async {
        guard app.data != nil else { return }
        app.refreshWatch()
        await sync.synchronize()
    }

    /// El reloj ha terminado el entreno de `day`: se termina aquí también, sin preguntar. Puede
    /// llegar con la app recién despertada por el reloj, en segundo plano y sin la pantalla, así
    /// que carga los datos si aún no lo estaban.
    public func workoutFinishedOnWatch(on day: LocalDate) async {
        await app.start()
        guard app.data != nil else { return }
        await today.finishFromWatch(on: day)
    }

    /// Al volver la red.
    public func reconnected() async {
        await sync.synchronize()
    }

    /// Al irse a segundo plano: lo tecleado se aplica y lo pendiente de subir sale ya
    /// (`beforeunload` en la PWA).
    public func wentToBackground() async {
        await today.commitTyping()
        await sync.flush()
    }
}
