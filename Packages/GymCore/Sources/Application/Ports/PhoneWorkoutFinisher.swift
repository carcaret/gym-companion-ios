import Domain

/// Puerto: desde el reloj, pedir al iPhone que termine el entreno de `day`, que se ha terminado en
/// el reloj (en Apple, WatchConnectivity). Si el iPhone no está a tiro, lo recibe cuando vuelva.
public protocol PhoneWorkoutFinisher: Sendable {
    func requestFinish(on day: LocalDate)
}
