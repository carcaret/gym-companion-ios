import Application
import Domain
import Testing

/// Lo que cualquier `RemoteHealthRecordStore` tiene que cumplir, con las reglas del `sha` de la
/// API de contenidos de GitHub. `makeStore` da un remoto vacío (sin fichero).
public enum RemoteHealthRecordStoreContract: String, CaseIterable, Sendable, CustomTestStringConvertible {
    case missingIs404 = "sin fichero, leer dice que no existe"
    case createsAndReads = "subir sin versión crea el fichero y se lee igual"
    case replacesCurrent = "subir encima de la versión actual la sustituye"
    case staleIsConflict = "subir encima de una versión vieja es un conflicto"
    case missingVersionIsConflict = "subir sin versión encima de un fichero que existe es un conflicto"

    public var testDescription: String { rawValue }

    public func verify(makeStore: () throws -> (any RemoteHealthRecordStore, SyncLocation, String)) async throws {
        let (store, location, token) = try makeStore()
        let sample = Self.sample
        let day = LocalDate(year: 2026, month: 11, day: 1)!
        switch self {
        case .missingIs404:
            await #expect(throws: RemoteError.notFound) { try await store.fetch(location, token: token) }
        case .createsAndReads:
            let version = try await store.push(sample, to: location, token: token, replacing: nil, on: day)
            #expect(try await store.fetch(location, token: token) == RemoteHealthSnapshot(record: sample, version: version))
        case .replacesCurrent:
            let first = try await store.push(HealthRecord(), to: location, token: token, replacing: nil, on: day)
            let second = try await store.push(sample, to: location, token: token, replacing: first, on: day)
            #expect(second != first)
            #expect(try await store.fetch(location, token: token) == RemoteHealthSnapshot(record: sample, version: second))
        case .staleIsConflict:
            let first = try await store.push(HealthRecord(), to: location, token: token, replacing: nil, on: day)
            _ = try await store.push(sample, to: location, token: token, replacing: first, on: day)
            await #expect(throws: RemoteError.conflict) {
                try await store.push(HealthRecord(), to: location, token: token, replacing: first, on: day)
            }
            #expect(try await store.fetch(location, token: token).record == sample)
        case .missingVersionIsConflict:
            _ = try await store.push(sample, to: location, token: token, replacing: nil, on: day)
            await #expect(throws: RemoteError.conflict) {
                try await store.push(HealthRecord(), to: location, token: token, replacing: nil, on: day)
            }
        }
    }

    /// Un poco de todo lo que guarda: una báscula con aparato y otra sin él (con un peso de día
    /// entero), pesajes completos y a medias, cintura y nutrición con y sin macros.
    public static let sample: HealthRecord = HealthFixtures.record
}
