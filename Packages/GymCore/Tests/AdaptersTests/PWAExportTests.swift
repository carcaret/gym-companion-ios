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

    @Test("ida y vuelta sin pérdidas con el fixture de la PWA")
    func fixtureRoundTrip() throws {
        let imported = try PWAFormat.trainingData(from: fixture())
        #expect(try PWAFormat.trainingData(from: PWAFormat.json(from: imported)) == imported)
    }

    @Test("ida y vuelta sin pérdidas con todas las variantes del modelo")
    func sampleRoundTrip() throws {
        // Las rutinas que no son DIA1–DIA3 no tienen nombre en db.json (ver el `sample` del contrato).
        let sample = RemoteTrainingDataSourceContract.sample
        #expect(try PWAFormat.trainingData(from: PWAFormat.json(from: sample)) == sample)
    }

    @Test("el fixture vuelve a db.json con los mismos datos que tenía")
    func fixtureSameJSON() throws {
        let original = try #require(JSONValue(parsing: fixture()))
        let exported = try #require(JSONValue(parsing: PWAFormat.json(from: PWAFormat.trainingData(from: fixture()))))
        // El fixture no tiene `pendingSwaps` y la exportación siempre lo escribe (vacío).
        #expect(exported["pendingSwaps"] == [:])
        #expect(exported["exercises"] == original["exercises"])
        #expect(exported["routines"] == original["routines"])
        #expect(exported["history"] == original["history"])
    }

    @Test("campos y orden de db.json: el nombre copiado en cada log y los opcionales solo si hacen falta")
    func format() throws {
        let data = TrainingData(
            catalog: Catalog([Exercise(id: "curl", name: "Curl Bíceps", group: .biceps, secondaryGroups: []), Exercise(id: "remo", name: "Remo")]),
            routines: [Routine(id: "DIA1", name: "Full Body - Día 1", exerciseIDs: ["curl"])],
            pendingSwaps: ["DIA1": PendingSwap(from: "curl", to: "remo", weekStart: LocalDate(year: 2026, month: 10, day: 19)!)],
            history: [Session(date: LocalDate(year: 2026, month: 10, day: 20)!, routineID: "DIA1", completed: true, logs: [
                ExerciseLog(exerciseID: "curl", series: 2, targetReps: 10, actualReps: [10, nil], weight: 18.1),
                ExerciseLog(exerciseID: "remo", series: 1, targetReps: 8, actualReps: [8], weight: 40, skipped: true, swappedFrom: "curl", oneOff: true),
            ])]
        )
        #expect(String(decoding: PWAFormat.json(from: data), as: UTF8.self) == """
        {
          "exercises": {
            "curl": {
              "id": "curl",
              "name": "Curl Bíceps",
              "grupo": "biceps",
              "secundarios": []
            },
            "remo": {
              "id": "remo",
              "name": "Remo"
            }
          },
          "routines": {
            "DIA1": [
              "curl"
            ]
          },
          "history": [
            {
              "date": "2026-10-20",
              "type": "DIA1",
              "logs": [
                {
                  "exercise_id": "curl",
                  "name": "Curl Bíceps",
                  "series": 2,
                  "reps": {
                    "expected": 10,
                    "actual": [
                      10,
                      null
                    ]
                  },
                  "weight": 18.1
                },
                {
                  "exercise_id": "remo",
                  "name": "Remo",
                  "series": 1,
                  "reps": {
                    "expected": 8,
                    "actual": [
                      8
                    ]
                  },
                  "weight": 40,
                  "skipped": true,
                  "swappedFrom": "curl",
                  "oneOff": true
                }
              ],
              "completed": true
            }
          ],
          "pendingSwaps": {
            "DIA1": {
              "fromExerciseId": "curl",
              "toExerciseId": "remo",
              "weekStart": "2026-10-19"
            }
          }
        }
        """)
    }

    @Test("el db.json real vuelve igual (si está la PWA clonada al lado)",
          .enabled(if: ProcessInfo.processInfo.environment["PWA_DB_JSON"] != nil))
    func realData() throws {
        let raw = try Data(contentsOf: URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["PWA_DB_JSON"])))
        let exported = PWAFormat.json(from: try PWAFormat.trainingData(from: raw))
        #expect(JSONValue(parsing: exported) == JSONValue(parsing: raw))
    }
}
