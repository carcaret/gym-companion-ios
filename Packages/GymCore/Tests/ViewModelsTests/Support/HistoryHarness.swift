import Application
import Domain
import GymCoreTesting
import ViewModels

/// Historial con el `db-test.json` de los e2e (o los datos que se pasen), sin GitHub.
@MainActor
struct HistoryHarness {
    let harness: SyncHarness
    let app: AppModel
    let model: HistoryModel

    static func make(_ data: TrainingData = PWATestDB.data, healthWorkouts: (any HealthWorkoutStore)? = nil) async -> HistoryHarness {
        let base = await AppHarness.start(local: data)
        return HistoryHarness(harness: base.harness, app: base.app,
                              model: HistoryModel(app: base.app, clock: base.clock, healthWorkouts: healthWorkouts))
    }

    var saved: TrainingData? {
        get async { await harness.savedLocally }
    }

    /// Abre la primera sesión de la lista (la más reciente) y su primera tarjeta.
    func openFirstAndExpand() {
        model.open(model.rows[0].date)
        model.toggleCard(0)
    }

    /// Abre la primera sesión, su primera tarjeta y pasa a editar.
    func openFirstAndEdit() {
        openFirstAndExpand()
        model.startEditing()
    }
}
