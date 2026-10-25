#if canImport(Security)
import Application
import Foundation
import Security

/// El token de GitHub en el Llavero del iPhone: solo en este aparato y disponible tras el primer
/// desbloqueo (la app puede subir en segundo plano, pero el token no sale del iPhone ni en copias).
///
/// Solo existe en plataformas de Apple; en Linux este fichero no compila nada.
public struct KeychainCredentialStore: CredentialStore {
    private let service: String
    private let account = "github-token"

    public init(service: String = "com.carcaret.gymcompanion") {
        self.service = service
    }

    public func token() async throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw KeychainError(status: status) }
        return String(decoding: data, as: UTF8.self)
    }

    public func setToken(_ token: String?) async throws {
        let deleted = SecItemDelete(baseQuery as CFDictionary)
        guard deleted == errSecSuccess || deleted == errSecItemNotFound else { throw KeychainError(status: deleted) }
        guard let token else { return }
        var item = baseQuery
        item[kSecValueData as String] = Data(token.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }
}

public struct KeychainError: Error, Hashable {
    public let status: OSStatus
}
#endif
