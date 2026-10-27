import Application
import Domain
import GymCoreTesting
import ViewModels

/// Hoy con el `db-test.json` de los e2e (o los datos que se pasen), sin GitHub, el día de
/// `SyncFixtures.today`. Lo que en los e2e es "localStorage" es `saved` (lo guardado en local).
@MainActor
struct TodayHarness {
    let harness: SyncHarness
    let app: AppModel
    let sync: SyncModel
    let model: TodayModel

    static func make(_ data: TrainingData = PWATestDB.data, configured: Bool = false) async -> TodayHarness {
        let harness = SyncHarness(local: data, configured: configured)
        let repository = harness.repository()
        let app = AppModel(repository: repository)
        let sync = SyncModel(repository: repository, app: app)
        await app.start()
        await sync.refresh()
        return TodayHarness(harness: harness, app: app, sync: sync, model: TodayModel(app: app, clock: FixedClock(SyncFixtures.today)))
    }

    var today: LocalDate { SyncFixtures.today }

    var saved: TrainingData? {
        get async { await harness.savedLocally }
    }

    /// La sesión de hoy guardada en local.
    var savedToday: Session? {
        get async { await saved?.history.session(on: SyncFixtures.today) }
    }

    /// Elegir la rutina y empezar (`selectRoutineAndStart` de los e2e).
    func start(_ routine: RoutineID = "DIA1") async {
        model.select(routine)
        await model.start()
    }

    /// El índice de la tarjeta de un ejercicio en el entreno.
    func index(of exercise: ExerciseID) -> Int? {
        model.activeCards.firstIndex { $0.exerciseID == exercise }
    }

    /// Terminar con todo relleno (`fillAllWorkoutReps` + finalizar): las reps ya vienen
    /// prerrellenadas al empezar.
    func finish() async {
        await model.finish()
    }
}
