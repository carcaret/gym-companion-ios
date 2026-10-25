import Application
import Domain
import Testing

/// Lo que cualquier `TrainingDataStore` tiene que cumplir. Cada adaptador lo pasa con su propio
/// test parametrizado:
///
/// ```swift
/// @Test(arguments: TrainingDataStoreContract.allCases)
/// func contract(_ check: TrainingDataStoreContract) async throws {
///     try await check.verify(makeStores: { … })
/// }
/// ```
///
/// `makeStores` devuelve una fábrica de stores que comparten el mismo sitio (un fichero, un
/// contenedor de iCloud…), recién vacío: cada llamada a la fábrica es como un arranque nuevo.
public enum TrainingDataStoreContract: String, CaseIterable, Sendable, CustomTestStringConvertible {
    case emptyLoadsNothing = "sin nada guardado, load devuelve nil"
    case savedLoads = "lo guardado se lee igual"
    case lastSaveWins = "lo último guardado gana"
    case survivesRestart = "otro arranque ve lo guardado"
    case keepsEveryField = "conserva todos los campos del modelo"

    public var testDescription: String { rawValue }

    public func verify(makeStores: () throws -> () -> any TrainingDataStore) async throws {
        let open = try makeStores()
        switch self {
        case .emptyLoadsNothing:
            #expect(try await open().load() == nil)
        case .savedLoads:
            let store = open()
            try await store.save(Self.sample)
            #expect(try await store.load() == Self.sample)
        case .lastSaveWins:
            let store = open()
            try await store.save(TrainingData())
            try await store.save(Self.sample)
            #expect(try await store.load() == Self.sample)
        case .survivesRestart:
            try await open().save(Self.sample)
            #expect(try await open().load() == Self.sample)
        case .keepsEveryField:
            try await open().save(Self.sample)
            let loaded = try #require(try await open().load())
            #expect(loaded.catalog == Self.sample.catalog)
            #expect(loaded.routines == Self.sample.routines)
            #expect(loaded.pendingSwaps == Self.sample.pendingSwaps)
            #expect(loaded.history == Self.sample.history)
        }
    }

    /// Datos con todas las variantes del modelo: secundarios sin tocar y vacíos, grupo
    /// desconocido, series vacías, pesos con decimales, saltados, cambiados, puntuales, entreno
    /// en curso, cambio recíproco pendiente y rutinas en un orden que no es el alfabético.
    public static let sample = TrainingData(
        catalog: Catalog([
            Exercise(id: "press_banca", name: "Press Banca", group: .pecho),
            Exercise(id: "jalon_al_pecho", name: "Jalón al pecho", group: .espalda, secondaryGroups: []),
            Exercise(id: "curl", name: "Curl Bíceps", group: .biceps, secondaryGroups: [.hombros, .core]),
            Exercise(id: "raro", name: "Raro", group: "otro"),
            Exercise(id: "sin_grupo", name: "Sin grupo"),
        ]),
        routines: [
            Routine(id: "DIA2", name: "Piernas", exerciseIDs: ["sin_grupo"]),
            Routine(id: "DIA1", name: "Full Body - Día 1", exerciseIDs: ["press_banca", "curl"]),
            Routine(id: "EXTRA", name: "Extra", exerciseIDs: []),
        ],
        pendingSwaps: ["DIA2": PendingSwap(from: "sin_grupo", to: "curl", weekStart: LocalDate(year: 2026, month: 10, day: 19)!)],
        history: [
            Session(date: LocalDate(year: 2026, month: 10, day: 20)!, routineID: "DIA1", completed: true, logs: [
                ExerciseLog(exerciseID: "press_banca", series: 3, targetReps: 10, actualReps: [10, 9, nil], weight: 52.5),
                ExerciseLog(exerciseID: "jalon_al_pecho", series: 4, targetReps: 12, actualReps: [], weight: 18.1,
                            skipped: true, swappedFrom: "curl", oneOff: true),
            ]),
            Session(date: LocalDate(year: 2026, month: 10, day: 25)!, routineID: "DIA2", completed: false, logs: [
                ExerciseLog(exerciseID: "sin_grupo", series: 1, targetReps: 1, actualReps: [nil], weight: 0),
            ]),
        ]
    )
}
