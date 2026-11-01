import Application
import Domain
import GymCoreTesting
import Presentation
import Testing
import ViewModels

@MainActor
private struct HealthHarness {
    let base: AppHarness
    let health: InMemoryHealthSampleSource
    let remote: InMemoryHealthRecordRemote.Storage
    let model: HealthModel

    static func make(configured: Bool = true, samples: [HealthSample] = HealthFixtures.samples) async -> HealthHarness {
        let base = await AppHarness.start(SyncHarness(configured: configured))
        let health = InMemoryHealthSampleSource(samples)
        let remote = InMemoryHealthRecordRemote.Storage()
        let export = HealthExport(source: health, remote: InMemoryHealthRecordRemote(storage: remote), repository: base.repository,
                                  clock: base.clock)
        return HealthHarness(base: base, health: health, remote: remote, model: HealthModel(export: export))
    }

    var lifecycle: AppLifecycle {
        AppLifecycle(app: base.app, sync: base.sync, today: TodayModel(app: base.app, clock: base.clock), health: model)
    }
}

@MainActor
@Suite("Lo de Salud en los ajustes")
struct HealthModelTests {
    @Test("antes de mirar, «Comprobando…»; después, lo que hay y si se ha subido")
    func status() async {
        let harness = await HealthHarness.make()
        #expect(harness.model.statusText == HealthText.checking)
        await harness.model.refresh()
        #expect(harness.model.statusText == HealthText.uploaded(HealthFixtures.record.summary))
        await harness.model.refresh()
        #expect(harness.model.statusText == HealthText.upToDate(HealthFixtures.record.summary))
    }

    @Test("sin GitHub lo dice")
    func notConfigured() async {
        let harness = await HealthHarness.make(configured: false)
        await harness.model.refresh()
        #expect(harness.model.statusText == HealthText.notConfigured)
    }

    @Test("sin datos (o sin permiso) dice que revise los permisos")
    func empty() async {
        let harness = await HealthHarness.make(samples: [])
        await harness.model.refresh()
        #expect(harness.model.statusText == HealthText.empty)
    }

    @Test("sin Salud o con un error al leerlo, lo dice")
    func unreadable() async {
        let harness = await HealthHarness.make()
        harness.health.fail(.unavailable)
        await harness.model.refresh()
        #expect(harness.model.statusText == HealthText.unavailable)
        harness.health.fail(.failed)
        await harness.model.refresh()
        #expect(harness.model.statusText == HealthText.readFailed)
    }

    @Test("sin red, que se subirá al volver; con otro error, que no se pudo")
    func uploadFailures() async {
        let harness = await HealthHarness.make()
        await harness.remote.fail(fetch: .unreachable)
        await harness.model.refresh()
        #expect(harness.model.statusText == HealthText.offline)
        await harness.remote.fail(fetch: .unauthorized)
        await harness.model.refresh()
        #expect(harness.model.statusText == HealthText.uploadFailed)
    }

    @Test("al arrancar la app se sube")
    func launch() async {
        let harness = await HealthHarness.make()
        await harness.lifecycle.launch()
        #expect(await harness.remote.pushes.count == 1)
    }

    @Test("al volver a la app se sube lo nuevo de Salud")
    func becameActive() async {
        let harness = await HealthHarness.make()
        await harness.lifecycle.launch()
        harness.health.samples += HealthFixtures.weighing("p3", at: HealthFixtures.at(2026, 11, 2, 9, 0), weight: 73.4, fat: 19.8, lean: 58.9)
        await harness.lifecycle.becameActive()
        #expect(await harness.remote.pushes.count == 2)
    }
}
