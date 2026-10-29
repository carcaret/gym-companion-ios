import Application
import Domain
import Testing

/// Lo que cualquier `CredentialStore` tiene que cumplir. `makeStores` empieza sin token.
public enum CredentialStoreContract: String, CaseIterable, Sendable, CustomTestStringConvertible {
    case emptyHasNoToken = "sin nada guardado, sin token"
    case savedReads = "el token guardado se lee en otro arranque"
    case replaces = "guardar otro token sustituye al anterior"
    case deletes = "nil borra el token"

    public var testDescription: String { rawValue }

    public func verify(makeStores: () throws -> () -> any CredentialStore) async throws {
        let open = try makeStores()
        switch self {
        case .emptyHasNoToken:
            #expect(try await open().token() == nil)
        case .savedReads:
            try await open().setToken("ghp_uno")
            #expect(try await open().token() == "ghp_uno")
        case .replaces:
            try await open().setToken("ghp_uno")
            try await open().setToken("ghp_dos")
            #expect(try await open().token() == "ghp_dos")
        case .deletes:
            try await open().setToken("ghp_uno")
            try await open().setToken(nil)
            #expect(try await open().token() == nil)
            try await open().setToken(nil)
            #expect(try await open().token() == nil)
        }
    }
}
