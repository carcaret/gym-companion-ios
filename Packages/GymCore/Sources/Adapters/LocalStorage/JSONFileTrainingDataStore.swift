import Application
import Domain
import Foundation

/// Los datos en un fichero JSON (en la app, en Application Support, que se conserva al
/// reinstalar encima y entra en la copia de iCloud del iPhone sin necesitar entitlements).
///
/// Elegido frente a SwiftData: son unos cientos de sesiones de un solo aparato, se leen y
/// guardan enteras, y así el adaptador compila y se prueba en Linux. Se escribe de forma atómica
/// (`JSONFile.write`).
public struct JSONFileTrainingDataStore: TrainingDataStore {
    private let file: URL

    public init(file: URL) {
        self.file = file
    }

    /// `Application Support/GymCompanion/training-data.json` del usuario.
    public static func applicationSupport() throws -> JSONFileTrainingDataStore {
        JSONFileTrainingDataStore(file: try JSONFile.applicationSupport("training-data.json"))
    }

    public func load() async throws -> TrainingData? {
        guard let contents = try JSONFile.read(file) else { return nil }
        let stored = try JSONDecoder().decode(StoredTrainingData.self, from: contents)
        return try stored.trainingData()
    }

    public func save(_ data: TrainingData) async throws {
        try write(data)
    }

    /// Lo mismo que `save`, sin esperar (los datos de ejemplo, antes de arrancar).
    public func write(_ data: TrainingData) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try JSONFile.write(encoder.encode(StoredTrainingData(data)), to: file)
    }
}
