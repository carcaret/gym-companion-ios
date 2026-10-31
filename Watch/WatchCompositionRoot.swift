import Adapters
import Application
import Domain
import Foundation
import HealthAdapters
import ViewModels
import WatchAdapters

/// Raíz de composición del reloj: el único sitio de la app del reloj que conoce los adaptadores
/// concretos. Escucha al iPhone desde que arranca la app, también en segundo plano: lo que enseña
/// y los entrenos que hay que borrar de Salud (los guardó el reloj, así que solo él puede). Lo que
/// se termina aquí se lo pide terminar al iPhone. Con
/// `-demo` (o `-demo-sin-entreno`) enseña datos de ejemplo, mide un entreno de mentira y no escucha
/// al iPhone (solo para las capturas del CI).
@MainActor
final class WatchCompositionRoot {
    let model: WatchModel
    private let demo: WatchSnapshot?
    /// Fuera de la demo: lo que envía el iPhone.
    private let receiver: WatchConnectivityReceiver?
    /// Cuántos borrados de Salud están en marcha.
    private var deleting = 0
    /// Días cuyo entreno no se ha encontrado, quizá por no tener aún permiso: se repiten al
    /// abrir la app, después de pedirlo.
    private var notFound: Set<LocalDate> = []
    private let healthWorkouts = HealthKitWorkoutStore()

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        let clock = SystemClock()
        demo = WatchDemo.snapshot(arguments: arguments, today: clock.today())
        if demo == nil {
            model = WatchModel(clock: clock, recorder: HealthKitWorkoutRecorder(), restAlert: WatchKitRestAlert(),
                               phone: WatchConnectivityWorkoutFinisher())
            let receiver = WatchConnectivityReceiver()
            self.receiver = receiver
            receiver.start()
            Task { await deleteWorkouts(from: receiver) }
        } else {
            model = WatchModel(clock: clock, recorder: DemoWorkoutRecorder(), restAlert: DemoRestAlert())
            receiver = nil
        }
    }

    /// Lo que llega del iPhone, mientras la app esté abierta. En la demo, el entreno ya empezado.
    func listen() async {
        if let demo {
            await model.receive(demo)
            if demo.workout != nil { await model.start() }
            return
        }
        guard let receiver else { return }
        // Con la app delante: la hoja de permisos de Salud, si falta alguno (en segundo plano no
        // puede salir), y lo que no se encontró sin ellos.
        Task {
            await healthWorkouts.requestAccess()
            let pending = notFound
            HealthLog.logger.notice("Permisos de Salud pedidos; pendientes: \(pending.count)")
            notFound = []
            for day in pending { await delete(day) }
        }
        for await snapshot in receiver.snapshots {
            await model.receive(snapshot)
        }
    }

    /// Al despertar en segundo plano por WatchConnectivity: espera a que llegue lo pendiente y se
    /// borre de Salud, como mucho 20 s (watchOS da poco tiempo).
    func finishPendingDeletions() async {
        guard let receiver else { return }
        let deadline = ContinuousClock.now + .seconds(20)
        while receiver.hasContentPending || deleting > 0, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    private func deleteWorkouts(from receiver: WatchConnectivityReceiver) async {
        for await day in receiver.workoutDeletions {
            await delete(day)
        }
    }

    /// Lo que no se puede borrar se queda en Salud; lo que no se encuentra se repite al abrir la
    /// app, mientras siga abierta en segundo plano.
    private func delete(_ day: LocalDate) async {
        deleting += 1
        var found = 0
        do {
            found = try await healthWorkouts.deleteAll(on: day)
            HealthLog.logger.notice("Borrar \(day.iso, privacy: .public): \(found) entrenos borrados")
        } catch {
            HealthLog.logger.error("Borrar \(day.iso, privacy: .public): \(String(describing: error), privacy: .public)")
        }
        if found == 0 { notFound.insert(day) }
        deleting -= 1
    }
}
