/// Puerto: desde el iPhone, abrir la app del reloj para que empiece a medir el entreno (en Apple,
/// `HKHealthStore.startWatchApp`). Si el reloj no está a tiro, no pasa nada: se empieza a mano.
public protocol WatchWorkoutLauncher: Sendable {
    func launch() async
}
