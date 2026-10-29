import Foundation
import Testing

/// El `db-test.json` de los e2e de la PWA, tal cual (`Fixtures/`).
func pwaTestDB() throws -> Data {
    let url = try #require(Bundle.module.url(forResource: "db-test", withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}
