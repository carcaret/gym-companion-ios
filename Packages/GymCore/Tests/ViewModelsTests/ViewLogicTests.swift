import Domain
import GymCoreTesting
import Presentation
import Testing
import ViewModels

// Lo que antes decidían las vistas de SwiftUI y ahora da el modelo, ya calculado.

@MainActor
@Suite("Lo que antes calculaba la vista")
struct ViewLogicTests {
    @Test("mover una tarjeta con lo que da onMove: hacia abajo, la posición de después")
    func moveCard() async {
        let today = await TodayHarness.make()
        await today.start()
        let before = today.model.activeCards.map(\.exerciseID)
        await today.model.moveCard(from: 0, toOffset: 2)
        #expect(today.model.activeCards.map(\.exerciseID) == [before[1], before[0]] + before.dropFirst(2))
        await today.model.moveCard(from: 1, toOffset: 0)
        #expect(today.model.activeCards.map(\.exerciseID) == before)
    }

    @Test("crear un ejercicio pide un nombre que no esté vacío")
    func canCreateExercise() async {
        let today = await TodayHarness.make()
        today.model.createName = "   "
        #expect(!today.model.canCreateExercise)
        today.model.createName = "Press Arnold"
        #expect(today.model.canCreateExercise)
    }

    @Test("la tarjeta da peso, series y objetivo con su texto y su error")
    func parameters() async {
        let today = await TodayHarness.make()
        await today.start()
        let card = today.model.activeCards[0]
        #expect(card.parameters.map(\.parameter) == [.weight, .series, .targetReps])
        #expect(card.parameters.map(\.value) == [LogText.kilograms(card.weight), "\(card.series)", "\(card.targetReps)"])
        #expect(card.parameters.map(\.isDecimal) == [true, false, false])
        #expect(card.parameters.allSatisfy { !$0.hasError })
    }
}

@Suite("Textos que montaban los modelos")
struct ModelTextTests {
    @Test("el peso con su unidad")
    func weight() {
        #expect(LogText.weight(60) == "60 kg")
        #expect(LogText.weight(52.5) == "52,5 kg")
    }

    @Test("series y sesiones de un ejercicio del grupo")
    func setsAndSessions() {
        #expect(ProgressText.setsAndSessions(sets: 12, sessions: 4) == "12 · 4")
    }

    @Test("las reps de las últimas sesiones, separadas")
    func recentReps() {
        #expect(ProgressText.recentReps(["11·11·10", "12·11·10"]) == "11·11·10  ·  12·11·10")
    }

    @Test("la versión instalada")
    func version() {
        #expect(SettingsText.version(AppVersion(marketing: "1.0", build: "231")) == "Versión 1.0 (231)")
    }

    @Test("el resumen del catálogo, con los que no tienen grupo solo si los hay")
    func catalogSummary() {
        #expect(CatalogText.summary(total: 4, withoutGroup: 1) == "4 en total · 1 sin grupo")
        #expect(CatalogText.summary(total: 4, withoutGroup: 0) == "4 en total")
    }
}
