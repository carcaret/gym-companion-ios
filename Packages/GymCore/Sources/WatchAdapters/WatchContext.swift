/// Las claves de lo que viaja por WatchConnectivity: en el `applicationContext`, lo que enseña el
/// reloj (en el formato de `WatchSnapshotCoding`); en un `userInfo`, el día cuyo entreno tiene que
/// borrar el reloj de Salud ("2026-10-30"); y del reloj al iPhone, en un mensaje o un `userInfo`,
/// el día del entreno terminado en el reloj.
enum WatchContext {
    static let snapshotKey = "snapshot"
    static let deleteWorkoutsKey = "deleteWorkoutsOn"
    static let finishWorkoutKey = "finishWorkoutOn"
}
