import Application
import Domain

/// Doble del Llavero.
public struct InMemoryCredentialStore: CredentialStore {
    public actor Storage {
        public private(set) var token: String?
        /// Guardar falla, como un Llavero que no deja escribir.
        public private(set) var failsToSave = false

        public init(_ token: String? = nil) {
            self.token = token
        }

        public func failSaving() {
            failsToSave = true
        }

        func set(_ token: String?) throws {
            if failsToSave { throw SaveFailure() }
            self.token = token
        }
    }

    public struct SaveFailure: Error {}

    public let storage: Storage

    public init(storage: Storage = Storage()) {
        self.storage = storage
    }

    public func token() async throws -> String? { await storage.token }
    public func setToken(_ token: String?) async throws { try await storage.set(token) }
}
