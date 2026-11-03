import Domain

/// Puerto: desde el reloj, pedir al iPhone que empiece el entreno de una rutina, que ya se mide en
/// el reloj (en Apple, WatchConnectivity). Si el iPhone no está a tiro, lo recibe cuando vuelva.
public protocol PhoneWorkoutStarter: Sendable {
    func requestStart(_ request: PhoneWorkoutStart)
}

/// Lo empezado en el reloj: la rutina y el día del entreno.
public struct PhoneWorkoutStart: Hashable, Sendable {
    public let routine: RoutineID
    public let day: LocalDate

    public init(routine: RoutineID, day: LocalDate) {
        self.routine = routine
        self.day = day
    }
}
