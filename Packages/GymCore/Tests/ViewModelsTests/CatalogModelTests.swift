import Application
import Domain
import GymCoreTesting
import Presentation
import Testing
import ViewModels

/// La DB de los e2e del catálogo: uno nunca entrenado y otro sin grupo.
private func catalogData() -> TrainingData {
    TrainingData(
        catalog: Catalog([
            Exercise(id: "press_banca", name: "Press Banca", group: .pecho, secondaryGroups: []),
            Exercise(id: "jalon", name: "Jalón al Pecho", group: .espalda, secondaryGroups: []),
            Exercise(id: "nunca_entrenado", name: "Peso Muerto Rumano", group: .piernas, secondaryGroups: []),
            Exercise(id: "huerfano", name: "Ejercicio Huérfano", secondaryGroups: []),
        ]),
        routines: [
            Routine(id: "DIA1", name: "Full Body - Día 1", exerciseIDs: ["press_banca", "jalon"]),
            Routine(id: "DIA2", name: "Full Body - Día 2", exerciseIDs: ["press_banca"]),
            Routine(id: "DIA3", name: "Full Body - Día 3", exerciseIDs: ["jalon"]),
        ],
        history: [Session(date: SyncFixtures.today.adding(days: -7), routineID: "DIA1", completed: true, logs: [
            ExerciseLog(exerciseID: "press_banca", series: 4, targetReps: 10, actualReps: [10, 10, 9, 9], weight: 60),
        ])]
    )
}

@MainActor
private struct CatalogHarness {
    let harness: SyncHarness
    let app: AppModel
    let model: CatalogModel
    let progress: ProgressModel

    static func make() async -> CatalogHarness {
        let harness = SyncHarness(local: catalogData(), configured: false)
        let app = AppModel(repository: harness.repository())
        await app.start()
        return CatalogHarness(harness: harness, app: app, model: CatalogModel(app: app),
                              progress: ProgressModel(app: app, clock: FixedClock(SyncFixtures.today)))
    }

    var rows: [CatalogModel.Row] { model.sections.flatMap(\.rows) }
}

// tests/e2e/catalogo.spec.js
@MainActor
@Suite("Catálogo de ejercicios")
struct CatalogTests {
    @Test("Progreso muestra la tarjeta del catálogo con el total y los sin grupo")
    func card() async {
        let catalog = await CatalogHarness.make()
        #expect(CatalogText.cardTitle == "Catálogo de ejercicios")
        #expect(CatalogText.total(catalog.model.total) == "4 en total")
        #expect(CatalogText.withoutGroup(catalog.model.withoutGroup) == "1 sin grupo")
    }

    @Test("lista todos los ejercicios de la DB, entrenados o no")
    func all() async {
        let catalog = await CatalogHarness.make()
        #expect(catalog.rows.count == 4)
        #expect(catalog.rows.contains { $0.name == "Peso Muerto Rumano" })
        // «Sin grupo», sin los paréntesis de la PWA (cambiado con la aprobación del usuario, 2026-10-27).
        #expect(catalog.model.sections.contains { $0.title == "Sin grupo" })
    }

    @Test("el buscador filtra ignorando tildes")
    func search() async {
        let catalog = await CatalogHarness.make()
        catalog.model.query = "jalon"
        #expect(catalog.rows.map(\.name) == ["Jalón al Pecho"])
    }

    @Test("volver deja Progreso como estaba")
    func back() async {
        let catalog = await CatalogHarness.make()
        catalog.model.query = "jalon"
        catalog.model.leave()
        #expect(catalog.model.query.isEmpty)
        #expect(StatsText.exercisesTitle == "Ejercicios")
        // Como su pestaña (la PWA: «Estadísticas»; cambio aprobado por el usuario, 2026-10-27).
        #expect(StatsText.title == "Progreso")
    }

    @Test("renombrar un ejercicio se propaga al resto de la app")
    func rename() async throws {
        let catalog = await CatalogHarness.make()
        catalog.model.edit("press_banca")
        catalog.model.editor?.name = "Press Banca Plano"
        await catalog.model.save()
        #expect(catalog.rows.contains { $0.name == "Press Banca Plano" })
        #expect(await catalog.harness.savedLocally?.catalog["press_banca"]?.name == "Press Banca Plano")
        let today = TodayModel(app: catalog.app, clock: FixedClock(SyncFixtures.today))
        #expect(today.routineRows.contains { $0.subtitle.contains("Press Banca Plano") })
    }

    @Test("cambiar el grupo mueve el ejercicio de sección")
    func changeGroup() async throws {
        let catalog = await CatalogHarness.make()
        catalog.model.edit("huerfano")
        catalog.model.setGroup(.core)
        await catalog.model.save()
        #expect(!catalog.model.sections.contains { $0.title == "Sin grupo" })
        let core = try #require(catalog.model.sections.first { $0.title == "Core" })
        #expect(core.rows.map(\.name) == ["Ejercicio Huérfano"])
    }

    @Test("marcar un secundario alimenta la barra de indirecto de Progreso")
    func secondaryFeedsProgress() async throws {
        let catalog = await CatalogHarness.make()
        catalog.model.edit("press_banca")
        catalog.model.toggleSecondary(.triceps)
        await catalog.model.save()
        #expect(catalog.rows.first { $0.exerciseID == "press_banca" }?.secondaries == ["Tríceps"])
        catalog.model.leave()
        let triceps = try #require(catalog.progress.groups.first { $0.name == "Tríceps" })
        #expect(triceps.total == 2)
    }

    @Test("el grupo principal no se puede marcar además como secundario")
    func primaryDisabled() async {
        let catalog = await CatalogHarness.make()
        catalog.model.edit("press_banca")
        #expect(catalog.model.chips.first { $0.group == .pecho }?.isEnabled == false)
        #expect(catalog.model.chips.first { $0.group == .triceps }?.isEnabled == true)
    }

    @Test("un nombre vacío no se guarda")
    func emptyName() async {
        let catalog = await CatalogHarness.make()
        catalog.model.edit("jalon")
        catalog.model.editor?.name = "   "
        // «Guardar» desactivado, sin aviso (2026-10-27, con la aprobación del usuario).
        #expect(!catalog.model.canSave)
        await catalog.model.save()
        #expect(catalog.model.editor != nil)
        #expect(catalog.app.notice == nil)
        catalog.model.editor?.name = "Jalón"
        #expect(catalog.model.canSave)
        catalog.model.cancelEditing()
        #expect(catalog.rows.contains { $0.name == "Jalón al Pecho" })
    }
}

@MainActor
@Suite("Catálogo: editor")
struct CatalogEditorTests {
    @Test("elegir como principal un grupo marcado como secundario lo apaga")
    func primaryTurnsOffSecondary() async {
        let catalog = await CatalogHarness.make()
        catalog.model.edit("press_banca")
        catalog.model.toggleSecondary(.triceps)
        catalog.model.setGroup(.triceps)
        #expect(catalog.model.editor?.secondaries == [])
        #expect(catalog.model.chips.first { $0.group == .triceps }?.isOn == false)
    }

    @Test("el editor arranca con los secundarios por defecto si nadie los ha tocado")
    func defaults() async {
        var data = catalogData()
        data.catalog = Catalog(data.catalog.all + [Exercise(id: "jalon_al_pecho", name: "Jalón", group: .espalda)])
        let harness = SyncHarness(local: data, configured: false)
        let app = AppModel(repository: harness.repository())
        await app.start()
        let model = CatalogModel(app: app)
        model.edit("jalon_al_pecho")
        #expect(model.editor?.secondaries == [.biceps])
    }

    // Antes avisaba «Ejercicio actualizado», como la PWA (quitado con la aprobación del usuario,
    // 2026-10-26).
    @Test("guardar no avisa: la hoja se cierra y la fila ya se ve cambiada")
    func notice() async {
        let catalog = await CatalogHarness.make()
        catalog.model.edit("jalon")
        await catalog.model.save()
        #expect(catalog.app.notice == nil)
        #expect(catalog.model.editor == nil)
    }

    @Test("sin coincidencias no hay secciones (y la vista lo dice con la búsqueda de iOS)")
    func noMatches() async {
        let catalog = await CatalogHarness.make()
        catalog.model.query = "zzz"
        #expect(catalog.model.sections.isEmpty)
    }

    @Test("sin ejercicios no hay secciones, y la vista dice que aún no hay")
    func empty() async {
        let app = AppModel(repository: SyncHarness(local: TrainingData(), configured: false).repository())
        await app.start()
        #expect(CatalogModel(app: app).sections.isEmpty)
        #expect(CatalogText.empty == "Aún no hay ejercicios")
    }
}
