import Application
import Domain
import Testing

/// Lo que cualquier `RemoteTrainingDataSource` tiene que cumplir, con las reglas del `sha` de la
/// API de contenidos de GitHub. `makeSource` da un remoto vacío (sin fichero).
public enum RemoteTrainingDataSourceContract: String, CaseIterable, Sendable, CustomTestStringConvertible {
    case missingIs404 = "sin fichero, leer dice que no existe"
    case createsAndReads = "subir sin versión crea el fichero y se lee igual"
    case replacesCurrent = "subir encima de la versión actual la sustituye"
    case staleIsConflict = "subir encima de una versión vieja es un conflicto"
    case missingVersionIsConflict = "subir sin versión encima de un fichero que existe es un conflicto"

    public var testDescription: String { rawValue }

    public func verify(makeSource: () throws -> (any RemoteTrainingDataSource, SyncLocation, String)) async throws {
        let (source, location, token) = try makeSource()
        let sample = Self.sample
        let day = LocalDate(year: 2026, month: 10, day: 25)!
        switch self {
        case .missingIs404:
            await #expect(throws: RemoteError.notFound) { try await source.fetch(location, token: token) }
        case .createsAndReads:
            let version = try await source.push(sample, to: location, token: token, replacing: nil, on: day)
            #expect(try await source.fetch(location, token: token) == RemoteSnapshot(data: sample, version: version))
        case .replacesCurrent:
            let first = try await source.push(TrainingData(), to: location, token: token, replacing: nil, on: day)
            let second = try await source.push(sample, to: location, token: token, replacing: first, on: day)
            #expect(second != first)
            #expect(try await source.fetch(location, token: token) == RemoteSnapshot(data: sample, version: second))
        case .staleIsConflict:
            let first = try await source.push(TrainingData(), to: location, token: token, replacing: nil, on: day)
            _ = try await source.push(sample, to: location, token: token, replacing: first, on: day)
            await #expect(throws: RemoteError.conflict) {
                try await source.push(TrainingData(), to: location, token: token, replacing: first, on: day)
            }
            #expect(try await source.fetch(location, token: token).data == sample)
        case .missingVersionIsConflict:
            _ = try await source.push(sample, to: location, token: token, replacing: nil, on: day)
            await #expect(throws: RemoteError.conflict) {
                try await source.push(TrainingData(), to: location, token: token, replacing: nil, on: day)
            }
        }
    }

    /// `TrainingDataStoreContract.sample` con lo que el `db.json` de la PWA puede guardar: las
    /// rutinas DIA1–DIA3 con su nombre y en su orden, y las demás detrás con el id por nombre.
    public static let sample: TrainingData = {
        var sample = TrainingDataStoreContract.sample
        sample.routines = [
            Routine(id: "DIA1", name: "Full Body - Día 1", exerciseIDs: ["press_banca", "curl"]),
            Routine(id: "DIA2", name: "Full Body - Día 2", exerciseIDs: ["sin_grupo"]),
            Routine(id: "EXTRA", name: "EXTRA", exerciseIDs: []),
        ]
        return sample
    }()
}
