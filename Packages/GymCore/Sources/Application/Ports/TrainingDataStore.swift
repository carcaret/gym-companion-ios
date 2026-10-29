import Domain

/// Puerto de almacenamiento: dónde viven los datos del usuario entre arranques.
///
/// Se lee y se guarda todo de una vez: son unos cientos de sesiones de un solo usuario en un
/// solo aparato. Lo implementa el fichero local (`Adapters`) y, si un día se paga la cuenta de
/// Apple, iCloud (#18).
public protocol TrainingDataStore: Sendable {
    /// Los datos guardados, o `nil` si aún no hay nada (primer arranque). Lanza si hay algo
    /// guardado que no se puede leer: en ese caso no hay que machacarlo.
    func load() async throws -> TrainingData?

    func save(_ data: TrainingData) async throws
}
