import Adapters
import Domain
import Foundation
import GymCoreTesting
import Testing

@Suite("Importación de db.json de la PWA")
struct PWAImportTests {
    private func fixture() throws -> Data {
        let url = try #require(Bundle.module.url(forResource: "db-test", withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    private func importing(_ json: String) throws -> TrainingData {
        try PWAFormat.trainingData(from: Data(json.utf8))
    }

    @Test("el fixture de la PWA: ejercicios, rutinas e historial")
    func fixtureImport() throws {
        let data = try PWAFormat.trainingData(from: fixture())
        #expect(data.catalog.ids == ["curl_biceps", "ejercicio_sin_historial", "press_banca", "sentadilla"])
        #expect(data.catalog["press_banca"] == Exercise(id: "press_banca", name: "Press Banca", group: .pecho))
        #expect(data.catalog["ejercicio_sin_historial"]?.group == "otro")
        #expect(data.routines == [
            Routine(id: "DIA1", name: "Full Body - Día 1", exerciseIDs: ["press_banca", "curl_biceps", "ejercicio_sin_historial"]),
            Routine(id: "DIA2", name: "Full Body - Día 2", exerciseIDs: ["sentadilla"]),
            Routine(id: "DIA3", name: "Full Body - Día 3", exerciseIDs: ["press_banca", "sentadilla"]),
        ])
        #expect(data.pendingSwaps.isEmpty)
        #expect(data.history.map(\.date.iso) == ["2024-01-08", "2024-01-10", "2024-01-05"])
        #expect(data.history[0].logs[0] == ExerciseLog(exerciseID: "press_banca", series: 3, targetReps: 10, actualReps: [10, 10, 8], weight: 60))
        #expect(data.history[2].logs[0].actualReps == [])
    }

    @Test("el fixture de la PWA es el PWATestDB de los tests de los ViewModels")
    func fixtureMatchesSwiftCopy() throws {
        #expect(try PWAFormat.trainingData(from: fixture()) == PWATestDB.data)
    }

    @Test("saltados, cambiados, puntuales y series vacías")
    func logVariants() throws {
        let data = try importing("""
        {"exercises": {"a": {"id": "a", "name": "A"}}, "history": [{"date": "2026-10-20", "type": "DIA1", "completed": false, "logs": [
          {"exercise_id": "a", "name": "A", "series": 3, "reps": {"expected": 8, "actual": [8, null, 7]}, "weight": 18.1,
           "skipped": true, "swappedFrom": "b", "oneOff": true}]}]}
        """)
        #expect(data.history == [Session(date: LocalDate(year: 2026, month: 10, day: 20)!, routineID: "DIA1", completed: false, logs: [
            ExerciseLog(exerciseID: "a", series: 3, targetReps: 8, actualReps: [8, nil, 7], weight: 18.1, skipped: true, swappedFrom: "b", oneOff: true),
        ])])
    }

    @Test("cambios recíprocos pendientes")
    func pendingSwaps() throws {
        let data = try importing("""
        {"exercises": {}, "history": [], "pendingSwaps": {"DIA3": {"fromExerciseId": "curl", "toExerciseId": "remo", "weekStart": "2026-07-13"}}}
        """)
        #expect(data.pendingSwaps == ["DIA3": PendingSwap(from: "curl", to: "remo", weekStart: LocalDate(year: 2026, month: 7, day: 13)!)])
    }

    @Test("ejercicios sin grupo y secundarios: ausentes, vacíos o editados")
    func groupsAndSecondaries() throws {
        let data = try importing("""
        {"exercises": {
          "a": {"id": "a", "name": "A"},
          "b": {"id": "b", "name": "B", "grupo": "", "secundarios": []},
          "c": {"id": "c", "name": "C", "grupo": "espalda", "secundarios": ["biceps", "hombros"]}
        }, "history": []}
        """)
        #expect(data.catalog["a"] == Exercise(id: "a", name: "A"))
        #expect(data.catalog["b"] == Exercise(id: "b", name: "B", group: nil, secondaryGroups: []))
        #expect(data.catalog["c"] == Exercise(id: "c", name: "C", group: .espalda, secondaryGroups: [.biceps, .hombros]))
    }

    @Test("DB vieja sin rutinas, sin pendientes ni campos opcionales de los logs")
    func oldDatabase() throws {
        let data = try importing("""
        {"exercises": {"a": {"id": "a", "name": "A"}}, "history": [{"date": "2026-01-02", "type": "DIA1", "logs": [
          {"exercise_id": "a", "series": 3, "reps": {"expected": 10}, "weight": 0}]}]}
        """)
        #expect(data.routines == Routine.defaults)
        #expect(data.pendingSwaps.isEmpty)
        // Sin `completed`: una sesión pasada que se terminó (el campo existe desde la primera
        // versión de la PWA; sin él no hay forma de que siga en curso).
        #expect(data.history[0].completed)
        #expect(data.history[0].logs[0] == ExerciseLog(exerciseID: "a", series: 3, targetReps: 10, actualReps: [], weight: 0))
    }

    @Test("un ejercicio del historial que ya no está en el catálogo conserva su nombre")
    func orphanLogs() throws {
        let data = try importing("""
        {"exercises": {}, "history": [{"date": "2026-01-02", "type": "DIA1", "completed": true, "logs": [
          {"exercise_id": "viejo", "name": "Ejercicio viejo", "series": 3, "reps": {"expected": 10, "actual": []}, "weight": 0}]}]}
        """)
        #expect(data.catalog["viejo"] == Exercise(id: "viejo", name: "Ejercicio viejo"))
    }

    @Test("rutinas que no son DIA1–DIA3 se conservan, detrás y con su id por nombre")
    func extraRoutines() throws {
        let data = try importing("""
        {"exercises": {}, "history": [], "routines": {"EXTRA": ["a"], "DIA2": ["b"], "DIA1": []}}
        """)
        #expect(data.routines == [
            Routine(id: "DIA1", name: "Full Body - Día 1"),
            Routine(id: "DIA2", name: "Full Body - Día 2", exerciseIDs: ["b"]),
            Routine(id: "EXTRA", name: "EXTRA", exerciseIDs: ["a"]),
        ])
    }

    @Test("sin exercises o sin history no es una DB de la PWA")
    func missingKeys() {
        #expect(throws: PWAFormatError.self) { try importing(#"{"history": []}"#) }
        #expect(throws: PWAFormatError.self) { try importing(#"{"exercises": {}}"#) }
    }

    @Test("una fecha que no existe da error, no se descarta en silencio")
    func invalidDate() {
        #expect(throws: PWAFormatError.invalidDate("2026-02-30")) {
            try importing(#"{"exercises": {}, "history": [{"date": "2026-02-30", "type": "DIA1", "completed": true, "logs": []}]}"#)
        }
    }

    /// `db.json` real de la PWA: `test.sh` y el CI lo pasan en `PWA_DB_JSON` (clon de carcaret/gym-companion).
    static let realDatabase = ProcessInfo.processInfo.environment["PWA_DB_JSON"].map(URL.init(fileURLWithPath:))

    @Test("los datos reales de la PWA se importan enteros", .enabled(if: realDatabase != nil, "sin PWA_DB_JSON"))
    func realData() throws {
        let json = try Data(contentsOf: try #require(Self.realDatabase))
        let raw = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        let data = try PWAFormat.trainingData(from: json)
        #expect(data.history.count == (raw["history"] as? [Any])?.count)
        #expect(data.catalog.ids.count >= ((raw["exercises"] as? [String: Any])?.count ?? 0))
        #expect(data.history.allSatisfy { !$0.logs.isEmpty })
    }
}
