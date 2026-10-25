import Application
import Domain
import GymCoreTesting
import Presentation
import Testing
import ViewModels

// En iOS tocar un botón no quita el foco del campo que se está editando (en la web sí, y el
// campo se aplicaba antes del toque): lo tecleado se aplica antes de cada acción.
@MainActor
@Suite("Lo tecleado en el entreno")
struct TodayTypingTests {
    private func started() async -> TodayHarness {
        let today = await TodayHarness.make()
        await today.start()
        today.model.toggleCard("press_banca")
        return today
    }

    @Test("teclear no guarda nada hasta salir del campo")
    func typingDoesNotSave() async throws {
        let today = await started()
        let before = try #require(await today.savedToday?.logs[0].weight)
        today.model.type(.weight, text: "88", at: 0)
        #expect(await today.savedToday?.logs[0].weight == before)
        await today.model.commitTyping()
        #expect(await today.savedToday?.logs[0].weight == 88)
        #expect(today.model.typed == nil)
    }

    @Test("finalizar con el teclado abierto guarda lo tecleado")
    func finishCommits() async throws {
        let today = await started()
        today.model.type(.weight, text: "88,5", at: 0)
        await today.model.finish()
        let session = try #require(await today.savedToday)
        #expect(session.completed)
        #expect(session.logs[0].weight == 88.5)
    }

    @Test("+ con el teclado abierto parte de lo tecleado")
    func adjustStartsFromTyped() async {
        let today = await started()
        today.model.type(.weight, text: "80", at: 0)
        await today.model.adjust(.weight, direction: 1, at: 0)
        #expect(today.model.activeCards[0].weight == 80 + ExerciseLog.weightStep(for: 80))
    }

    @Test("reordenar con el teclado abierto aplica lo tecleado al ejercicio en el que se tecleó")
    func reorderCommitsToTheRightExercise() async throws {
        let today = await started()
        today.model.type(.weight, text: "88", at: 0)
        await today.model.reorder(from: 0, to: 2)
        let logs = try #require(await today.savedToday?.logs)
        #expect(logs.first { $0.exerciseID == "press_banca" }?.weight == 88)
    }
}

@MainActor
@Suite("Lo tecleado en el historial")
struct HistoryTypingTests {
    @Test("Guardar con el teclado abierto guarda lo tecleado")
    func saveCommits() async {
        let history = await HistoryHarness.make()
        history.openFirstAndExpand()
        history.model.type(.weight, text: "75", at: 0)
        #expect(!history.model.cards[0].isDirty)
        await history.model.save(0)
        #expect(history.model.cards[0].subtitle.contains("75"))
    }

    @Test("salir del campo deja la tarjeta con cambios por guardar")
    func commitMarksDirty() async {
        let history = await HistoryHarness.make()
        history.openFirstAndExpand()
        history.model.type(.weight, text: "75", at: 0)
        history.model.commitTyping()
        #expect(history.model.cards[0].isDirty)
        #expect(history.model.cards[0].weight == 75)
    }

    @Test("volver a la lista descarta lo tecleado, como los demás cambios sin guardar")
    func backDiscards() async {
        let history = await HistoryHarness.make()
        history.openFirstAndExpand()
        history.model.type(.weight, text: "75", at: 0)
        history.model.back()
        #expect(history.model.typed == nil)
    }
}
