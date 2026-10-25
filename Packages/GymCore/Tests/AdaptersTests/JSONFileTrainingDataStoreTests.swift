import Adapters
import Application
import Domain
import Foundation
import GymCoreTesting
import Testing

@Suite("Almacenamiento en fichero JSON")
struct JSONFileTrainingDataStoreTests {
    private func temporaryFile() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        return directory.appendingPathComponent("datos/training-data.json")
    }

    @Test(arguments: TrainingDataStoreContract.allCases)
    func contract(_ check: TrainingDataStoreContract) async throws {
        try await check.verify(makeStores: {
            let file = try temporaryFile()
            return { JSONFileTrainingDataStore(file: file) }
        })
    }

    @Test("crea la carpeta si no existe")
    func createsDirectory() async throws {
        let file = try temporaryFile()
        try await JSONFileTrainingDataStore(file: file).save(TrainingData())
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test("un fichero que no se puede leer da error, no datos vacíos")
    func corrupt() async throws {
        let file = try temporaryFile()
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ no es json".utf8).write(to: file)
        await #expect(throws: (any Error).self) { try await JSONFileTrainingDataStore(file: file).load() }
    }

    @Test("una versión del formato que no conoce da error")
    func unknownVersion() async throws {
        let file = try temporaryFile()
        try await JSONFileTrainingDataStore(file: file).save(TrainingData())
        let text = try String(contentsOf: file, encoding: .utf8).replacingOccurrences(of: "\"version\" : 1", with: "\"version\" : 99")
        try Data(text.utf8).write(to: file)
        await #expect(throws: StoredFormatError.unsupportedVersion(99)) { try await JSONFileTrainingDataStore(file: file).load() }
    }

    @Test("el formato guardado es legible y lleva su versión")
    func readableFormat() async throws {
        let file = try temporaryFile()
        try await JSONFileTrainingDataStore(file: file).save(TrainingDataStoreContract.sample)
        let text = try String(contentsOf: file, encoding: .utf8)
        #expect(text.contains("\"version\" : 1"))
        #expect(text.contains("\"date\" : \"2026-10-20\""))
        #expect(text.contains("\"weekStart\" : \"2026-10-19\""))
    }
}
