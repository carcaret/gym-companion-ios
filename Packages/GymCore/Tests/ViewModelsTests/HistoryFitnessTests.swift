import Domain
import GymCoreTesting
import Presentation
import Testing
import ViewModels

// Borrar una sesión del Historial borra también su entreno de Fitness, si el reloj lo guardó en
// Salud (decisión del usuario, 2026-10-30). Solo los que guardó Gym.

@MainActor
@Suite("Borrar una sesión, también de Fitness")
struct HistoryFitnessTests {
    @Test("con un entreno de Gym en Salud ese día, el aviso dice que también se borra de Fitness")
    func promptMentionsFitness() async throws {
        let date = try await firstDate()
        let history = await HistoryHarness.make(healthWorkouts: InMemoryHealthWorkoutStore(days: [date]))
        await history.model.requestDelete(date)
        let prompt = try #require(history.model.deletePrompt)
        #expect(prompt.deletesFromFitness)
        #expect(prompt.message.hasSuffix("También se borra de Fitness."))
    }

    @Test("sin entreno en Salud ese día, el aviso no habla de Fitness")
    func promptWithoutFitness() async throws {
        let date = try await firstDate()
        let history = await HistoryHarness.make(healthWorkouts: InMemoryHealthWorkoutStore())
        await history.model.requestDelete(date)
        let prompt = try #require(history.model.deletePrompt)
        #expect(!prompt.deletesFromFitness)
        #expect(!prompt.message.contains("Fitness"))
    }

    @Test("al confirmar, borra la sesión y el entreno de Salud de ese día")
    func deletesWorkout() async throws {
        let date = try await firstDate()
        let health = InMemoryHealthWorkoutStore(days: [date])
        let history = await HistoryHarness.make(healthWorkouts: health)
        await history.model.requestDelete(date)
        try await history.model.confirmDelete(#require(history.model.deletePrompt))
        #expect(health.deleted == [date])
        #expect(!history.model.rows.contains { $0.date == date })
        #expect(history.app.notice == nil)
    }

    @Test("sin entreno en Salud, no intenta borrar nada")
    func nothingToDelete() async throws {
        let date = try await firstDate()
        let health = InMemoryHealthWorkoutStore()
        let history = await HistoryHarness.make(healthWorkouts: health)
        await history.model.requestDelete(date)
        try await history.model.confirmDelete(#require(history.model.deletePrompt))
        #expect(health.deleted.isEmpty)
    }

    @Test("si Salud no deja borrarlo, la sesión se borra igual y lo avisa")
    func deleteFails() async throws {
        let date = try await firstDate()
        let health = InMemoryHealthWorkoutStore(days: [date])
        health.failDeletes()
        let history = await HistoryHarness.make(healthWorkouts: health)
        await history.model.requestDelete(date)
        try await history.model.confirmDelete(#require(history.model.deletePrompt))
        #expect(!history.model.rows.contains { $0.date == date })
        #expect(history.app.notice == HistoryText.fitnessDeleteFailed)
    }

    private func firstDate() async throws -> LocalDate {
        try #require(await HistoryHarness.make().model.rows.first).date
    }
}
