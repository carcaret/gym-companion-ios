import Application
import Domain
import Foundation

/// Los datos en un fichero JSON (en la app, en Application Support, que se conserva al
/// reinstalar encima y entra en la copia de iCloud del iPhone sin necesitar entitlements).
///
/// Elegido frente a SwiftData: son unos cientos de sesiones de un solo aparato, se leen y
/// guardan enteras, y así el adaptador compila y se prueba en Linux. Cada guardado escribe un
/// fichero nuevo y lo cambia por el anterior de una vez (`.atomic`): un corte a mitad no deja
/// medio fichero.
public struct JSONFileTrainingDataStore: TrainingDataStore {
    private let file: URL

    public init(file: URL) {
        self.file = file
    }

    /// `Application Support/GymCompanion/training-data.json` del usuario.
    public static func applicationSupport() throws -> JSONFileTrainingDataStore {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return JSONFileTrainingDataStore(file: base.appendingPathComponent("GymCompanion/training-data.json"))
    }

    public func load() async throws -> TrainingData? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let stored = try JSONDecoder().decode(StoredTrainingData.self, from: Data(contentsOf: file))
        return try stored.trainingData()
    }

    public func save(_ data: TrainingData) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(StoredTrainingData(data)).write(to: file, options: .atomic)
    }
}
