import Adapters
import Domain
import Foundation
import GymCoreTesting
import Testing

@Suite("Exportación a db.json de la PWA")
struct PWAExportTests {
    private func fixture() throws -> Data {
        let url = try #require(Bundle.module.url(forResource: "db-test", withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    private func object(_ json: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])
    }

    @Test("ida y vuelta sin pérdidas con el fixture de la PWA")
    func fixtureRoundTrip() throws {
        let imported = try PWAFormat.trainingData(from: fixture())
        #expect(try PWAFormat.trainingData(from: PWAFormat.json(from: imported)) == imported)
    }

    @Test("ida y vuelta sin pérdidas con todas las variantes del modelo")
    func sampleRoundTrip() throws {
        let sample = TrainingDataStoreContract.sample
        let back = try PWAFormat.trainingData(from: PWAFormat.json(from: sample))
        #expect(back.catalog == sample.catalog)
        #expect(back.pendingSwaps == sample.pendingSwaps)
        #expect(back.history == sample.history)
        // db.json no guarda el nombre de las rutinas: vuelven las de siempre con el suyo y las
        // demás con su id.
        #expect(back.routines.map(\.id) == ["DIA1", "DIA2", "EXTRA"])
        #expect(back.routines.map(\.exerciseIDs) == [["press_banca", "curl"], ["sin_grupo"], []])
    }

    @Test("el JSON de la PWA da los mismos datos que el exportado (mismos campos y valores)")
    func sameAsPWA() throws {
        let original = try object(fixture())
        let exported = try object(PWAFormat.json(from: PWAFormat.trainingData(from: fixture())))
        #expect(NSDictionary(dictionary: exported["exercises"] as? [String: Any] ?? [:]) == NSDictionary(dictionary: original["exercises"] as? [String: Any] ?? [:]))
        #expect(NSDictionary(dictionary: exported["routines"] as? [String: Any] ?? [:]) == NSDictionary(dictionary: original["routines"] as? [String: Any] ?? [:]))
        #expect(NSArray(array: exported["history"] as? [Any] ?? []) == NSArray(array: original["history"] as? [Any] ?? []))
        #expect(NSDictionary(dictionary: exported["pendingSwaps"] as? [String: Any] ?? [:]) == NSDictionary())
    }

    @Test("cada log lleva el nombre del ejercicio, como en la PWA")
    func copiesName() throws {
        let data = TrainingData(catalog: Catalog([Exercise(id: "a", name: "Curl de bíceps — España")]),
                                history: [Session(date: LocalDate(year: 2026, month: 1, day: 2)!, routineID: "DIA1", completed: true,
                                                  logs: [ExerciseLog(exerciseID: "a", series: 1, targetReps: 1, actualReps: [1], weight: 0)])])
        let history = try #require(try object(PWAFormat.json(from: data))["history"] as? [[String: Any]])
        let log = try #require((history.first?["logs"] as? [[String: Any]])?.first)
        #expect(log["name"] as? String == "Curl de bíceps — España")
    }

    @Test("los opcionales solo aparecen cuando tienen valor, como los escribe la PWA")
    func optionalFields() throws {
        let data = TrainingData(catalog: Catalog([Exercise(id: "a", name: "A")]),
                                history: [Session(date: LocalDate(year: 2026, month: 1, day: 2)!, routineID: "DIA1", completed: true,
                                                  logs: [ExerciseLog(exerciseID: "a", series: 1, targetReps: 1, actualReps: [nil], weight: 0)])])
        let text = try #require(String(data: PWAFormat.json(from: data), encoding: .utf8))
        for key in ["grupo", "secundarios", "skipped", "swappedFrom", "oneOff"] { #expect(!text.contains("\"\(key)\""), "\(key)") }
        #expect(text.contains("\"actual\": [\n              null\n            ]"))
    }

    @Test("formato de JSON.stringify(db, null, 2): sangría de 2, claves en el orden de la PWA y pesos sin decimales de más")
    func layout() throws {
        let data = TrainingData(catalog: Catalog([Exercise(id: "a", name: "A", group: .pecho)]),
                                routines: [Routine(id: "DIA1", name: "x", exerciseIDs: ["a"])],
                                history: [Session(date: LocalDate(year: 2026, month: 1, day: 2)!, routineID: "DIA1", completed: true,
                                                  logs: [ExerciseLog(exerciseID: "a", series: 3, targetReps: 10, actualReps: [10], weight: 18.1)])])
        let text = try #require(String(data: PWAFormat.json(from: data), encoding: .utf8))
        #expect(text == """
        {
          "exercises": {
            "a": {
              "id": "a",
              "name": "A",
              "grupo": "pecho"
            }
          },
          "routines": {
            "DIA1": [
              "a"
            ]
          },
          "history": [
            {
              "date": "2026-01-02",
              "type": "DIA1",
              "completed": true,
              "logs": [
                {
                  "exercise_id": "a",
                  "name": "A",
                  "series": 3,
                  "reps": {
                    "expected": 10,
                    "actual": [
                      10
                    ]
                  },
                  "weight": 18.1
                }
              ]
            }
          ],
          "pendingSwaps": {}
        }
        """)
    }

    @Test("los datos reales de la PWA vuelven idénticos", .enabled(if: PWAImportTests.realDatabase != nil, "sin PWA_DB_JSON"))
    func realData() throws {
        let original = try Data(contentsOf: try #require(PWAImportTests.realDatabase))
        let exported = try PWAFormat.json(from: PWAFormat.trainingData(from: original))
        let a = try object(original), b = try object(exported)
        #expect(NSArray(array: b["history"] as? [Any] ?? []) == NSArray(array: a["history"] as? [Any] ?? []))
        #expect(NSDictionary(dictionary: b["exercises"] as? [String: Any] ?? [:]) == NSDictionary(dictionary: a["exercises"] as? [String: Any] ?? [:]))
        #expect(NSDictionary(dictionary: b["routines"] as? [String: Any] ?? [:]) == NSDictionary(dictionary: a["routines"] as? [String: Any] ?? [:]))
        // El texto no sale igual byte a byte: la PWA no escribe siempre las claves en el mismo
        // orden (en las sesiones antiguas `logs` va antes que `completed`) y añade los ejercicios
        // nuevos al final. La primera subida desde la app lo normaliza una vez.
    }
}
