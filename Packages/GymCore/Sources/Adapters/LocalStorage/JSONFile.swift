import Foundation

/// Lo común a los ficheros JSON de la app: dónde van y cómo se escriben.
enum JSONFile {
    /// `Application Support/GymCompanion/<name>` del usuario, que se conserva al reinstalar encima.
    static func applicationSupport(_ name: String) throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return base.appendingPathComponent("GymCompanion/\(name)")
    }

    /// Lo leído, o `nil` si el fichero no existe.
    static func read(_ file: URL) throws -> Data? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        return try Data(contentsOf: file)
    }

    /// Escribe un fichero nuevo y lo cambia por el anterior de una vez (`.atomic`): un corte a mitad
    /// no deja medio fichero.
    static func write(_ data: Data, to file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: file, options: .atomic)
    }
}
