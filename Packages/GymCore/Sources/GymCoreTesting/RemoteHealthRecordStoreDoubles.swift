import Application
import Domain

/// Doble del `salud.json` remoto: un solo fichero con su versión, como el de GitHub (subir encima
/// de una versión que no es la actual es un conflicto). Se le pueden programar fallos.
public struct InMemoryHealthRecordRemote: RemoteHealthRecordStore {
    public struct Push: Hashable, Sendable {
        public let record: HealthRecord
        public let location: SyncLocation
        public let replacing: RemoteVersion?
        public let day: LocalDate
    }

    public actor Storage {
        public private(set) var record: HealthRecord?
        public private(set) var version: RemoteVersion
        public private(set) var fetches: [SyncLocation] = []
        /// Las subidas que salieron bien.
        public private(set) var pushes: [Push] = []
        private var fetchFailure: RemoteError?
        private var pushFailure: RemoteError?
        private var counter = 0

        public init(_ record: HealthRecord? = nil, version: String = "sha_salud") {
            self.record = record
            self.version = RemoteVersion(version)
        }

        /// Los fallos que darán las siguientes peticiones (`nil` = funcionan).
        public func fail(fetch: RemoteError? = nil, push: RemoteError? = nil) {
            fetchFailure = fetch
            pushFailure = push
        }

        /// Alguien cambia el fichero por su cuenta.
        public func replace(with record: HealthRecord, version: String) {
            self.record = record
            self.version = RemoteVersion(version)
        }

        func fetch(_ location: SyncLocation) throws(RemoteError) -> RemoteHealthSnapshot {
            fetches.append(location)
            if let fetchFailure { throw fetchFailure }
            guard let record else { throw .notFound }
            return RemoteHealthSnapshot(record: record, version: version)
        }

        func push(_ new: HealthRecord, to location: SyncLocation, replacing: RemoteVersion?, day: LocalDate) throws(RemoteError)
            -> RemoteVersion {
            if let pushFailure { throw pushFailure }
            guard replacing == (record == nil ? nil : version) else { throw .conflict }
            counter += 1
            record = new
            version = RemoteVersion("sha_salud_\(counter)")
            pushes.append(Push(record: new, location: location, replacing: replacing, day: day))
            return version
        }
    }

    public let storage: Storage

    public init(storage: Storage = Storage()) {
        self.storage = storage
    }

    public func fetch(_ location: SyncLocation, token: String) async throws(RemoteError) -> RemoteHealthSnapshot {
        try await storage.fetch(location)
    }

    public func push(_ record: HealthRecord, to location: SyncLocation, token: String, replacing version: RemoteVersion?,
                     on day: LocalDate) async throws(RemoteError) -> RemoteVersion {
        try await storage.push(record, to: location, replacing: version, day: day)
    }
}
