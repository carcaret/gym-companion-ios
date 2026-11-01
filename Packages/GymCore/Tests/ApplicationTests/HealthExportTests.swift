import Application
import Domain
import GymCoreTesting
import Testing

// Lo de Salud, en el salud.json de GitHub junto al db.json (#104).

@Suite("Subir lo de Salud a GitHub")
struct HealthExportTests {
    private struct Harness {
        let sync: SyncHarness
        let health: InMemoryHealthSampleSource
        let remote: InMemoryHealthRecordRemote.Storage
        let export: HealthExport

        init(configured: Bool = true, samples: [HealthSample] = HealthFixtures.samples, remote: HealthRecord? = nil) async throws {
            sync = SyncHarness(configured: configured)
            let repository = sync.repository()
            _ = try await repository.start()
            health = InMemoryHealthSampleSource(samples)
            self.remote = .init(remote)
            export = HealthExport(source: health, remote: InMemoryHealthRecordRemote(storage: self.remote), repository: repository,
                                  clock: FixedClock(SyncFixtures.today))
        }
    }

    private let location = SyncFixtures.location.sibling(named: "salud.json")

    @Test("sube el salud.json junto al db.json, con lo que hay en Salud")
    func uploads() async throws {
        let harness = try await Harness()
        #expect(await harness.export.run() == .uploaded(HealthFixtures.record.summary))
        let push = try #require(await harness.remote.pushes.first)
        #expect(push.record == HealthFixtures.record)
        #expect(push.location == location)
        #expect(push.replacing == nil, "Aún no existía")
        #expect(push.day == SyncFixtures.today)
    }

    @Test("sin GitHub no lee Salud ni sube nada")
    func notConfigured() async throws {
        let harness = try await Harness(configured: false)
        #expect(await harness.export.run() == .notConfigured)
        #expect(harness.health.reads == 0, "Ni pide permiso")
        #expect(await harness.remote.fetches.isEmpty)
    }

    @Test("si Salud no se puede leer, no sube nada")
    func unreadable() async throws {
        let harness = try await Harness()
        harness.health.fail(.unavailable)
        #expect(await harness.export.run() == .unreadable(.unavailable))
        #expect(await harness.remote.pushes.isEmpty)
    }

    @Test("Salud vacío (o sin permiso) no machaca lo que hay en GitHub")
    func empty() async throws {
        let harness = try await Harness(samples: [], remote: HealthFixtures.record)
        #expect(await harness.export.run() == .empty)
        #expect(await harness.remote.pushes.isEmpty)
        #expect(await harness.remote.record == HealthFixtures.record)
    }

    @Test("si GitHub ya tiene lo mismo, no sube")
    func remoteUpToDate() async throws {
        let harness = try await Harness(remote: HealthFixtures.record)
        #expect(await harness.export.run() == .upToDate(HealthFixtures.record.summary))
        #expect(await harness.remote.pushes.isEmpty)
    }

    @Test("si GitHub tiene otra cosa, lo sustituye encima de su versión")
    func replaces() async throws {
        let harness = try await Harness(remote: HealthRecord())
        #expect(await harness.export.run() == .uploaded(HealthFixtures.record.summary))
        #expect(await harness.remote.pushes.first?.replacing == RemoteVersion("sha_salud"))
    }

    @Test("sin cambios en Salud, la siguiente vez ni pregunta a GitHub; con cambios, sube encima de lo suyo")
    func remembers() async throws {
        let harness = try await Harness()
        _ = await harness.export.run()
        #expect(await harness.export.run() == .upToDate(HealthFixtures.record.summary))
        #expect(await harness.remote.fetches.count == 1)
        #expect(await harness.remote.pushes.count == 1)

        harness.health.samples += HealthFixtures.weighing("p3", at: HealthFixtures.at(2026, 11, 2, 9, 0), weight: 73.4, fat: 19.8, lean: 58.9)
        #expect(await harness.export.run() == .uploaded(HealthRecord(samples: harness.health.samples).summary))
        #expect(await harness.remote.fetches.count == 1)
        #expect(await harness.remote.pushes.last?.replacing == RemoteVersion("sha_salud_1"))
    }

    @Test("si alguien cambió el fichero, es un conflicto; la siguiente vez pregunta la versión y sube")
    func conflict() async throws {
        let harness = try await Harness()
        _ = await harness.export.run()
        await harness.remote.replace(with: HealthRecord(), version: "sha_otro")
        harness.health.samples += HealthFixtures.weighing("p3", at: HealthFixtures.at(2026, 11, 2, 9, 0), weight: 73.4, fat: 19.8, lean: 58.9)
        #expect(await harness.export.run() == .failed(.conflict))
        #expect(await harness.export.run() == .uploaded(HealthRecord(samples: harness.health.samples).summary))
        #expect(await harness.remote.pushes.last?.replacing == RemoteVersion("sha_otro"))
    }

    @Test("sin red no sube, y lo intenta la siguiente vez")
    func unreachable() async throws {
        let harness = try await Harness()
        await harness.remote.fail(fetch: .unreachable)
        #expect(await harness.export.run() == .failed(.unreachable))
        await harness.remote.fail()
        #expect(await harness.export.run() == .uploaded(HealthFixtures.record.summary))
    }

    @Test("dos a la vez (arrancar y volver a la app) suben una sola vez")
    func concurrent() async throws {
        let harness = try await Harness()
        async let first = harness.export.run()
        async let second = harness.export.run()
        let results = await [first, second]
        #expect(results.allSatisfy { $0 == .uploaded(HealthFixtures.record.summary) || $0 == .upToDate(HealthFixtures.record.summary) })
        #expect(await harness.remote.pushes.count == 1)
    }
}

@Suite("SyncLocation: otro fichero junto al db.json")
struct SyncLocationSiblingTests {
    @Test("en la misma carpeta, rama y repositorio")
    func sibling() {
        #expect(SyncLocation(repository: "u/r", branch: "master", path: "db.json").sibling(named: "salud.json")
            == SyncLocation(repository: "u/r", branch: "master", path: "salud.json"))
        #expect(SyncLocation(repository: "u/r", branch: "main", path: "datos/gym/db.json").sibling(named: "salud.json")
            == SyncLocation(repository: "u/r", branch: "main", path: "datos/gym/salud.json"))
    }
}
