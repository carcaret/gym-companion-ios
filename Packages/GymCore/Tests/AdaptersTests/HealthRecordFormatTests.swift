import Adapters
import Domain
import Foundation
import GymCoreTesting
import Testing

@Suite("El salud.json")
struct HealthRecordFormatTests {
    private func text(_ record: HealthRecord) -> String {
        String(decoding: HealthRecordFormat.json(from: record), as: UTF8.self)
    }

    @Test("se escribe con dos espacios, las claves en español y en su orden, y sin lo que no hay")
    func writes() {
        let time = HealthFixtures.at(2026, 11, 1, 9, 27, 38)
        let record = HealthRecord(samples: HealthFixtures.weighing("p", at: time, weight: 73.3, fat: 19.8, lean: 58.79,
                                                                   device: HealthDevice(manufacturer: "Healthkeep", model: "FG2016LB"))
            + [HealthSample(id: "mf", quantity: .bodyMass, value: 72.8, start: HealthFixtures.at(2025, 7, 4, 0, 0),
                            end: HealthFixtures.at(2025, 7, 4, 23, 59, 59), source: HealthFixtures.macroFactor),
               HealthSample(id: "c", quantity: .waistCircumference, value: 82.5, start: time, source: HealthFixtures.fitdays),
               HealthSample(id: "k", quantity: .dietaryEnergy, value: 2531, start: time, source: HealthFixtures.macroFactor)])
        #expect(text(record) == """
        {
          "version": 1,
          "basculas": [
            {
              "id": "com.sbs.diet",
              "nombre": "MacroFactor",
              "origen": "com.sbs.diet",
              "primeraMedida": "2025-07-04",
              "ultimaMedida": "2025-07-04"
            },
            {
              "id": "com.fitdays.fitdays#FG2016LB",
              "nombre": "Fitdays",
              "origen": "com.fitdays.fitdays",
              "aparato": {
                "fabricante": "Healthkeep",
                "modelo": "FG2016LB"
              },
              "primeraMedida": "2026-11-01T09:27:38+01:00",
              "ultimaMedida": "2026-11-01T09:27:38+01:00"
            }
          ],
          "pesajes": [
            {
              "id": "mf",
              "fecha": "2025-07-04",
              "bascula": "com.sbs.diet",
              "pesoKg": 72.8
            },
            {
              "id": "p",
              "en": "2026-11-01T09:27:38+01:00",
              "bascula": "com.fitdays.fitdays#FG2016LB",
              "pesoKg": 73.3,
              "grasaPct": 19.8,
              "magraKg": 58.79
            }
          ],
          "cintura": [
            {
              "id": "c",
              "en": "2026-11-01T09:27:38+01:00",
              "cm": 82.5
            }
          ],
          "nutricion": [
            {
              "fecha": "2026-11-01",
              "origen": "MacroFactor",
              "kcal": 2531
            }
          ]
        }
        """)
    }

    @Test("sin nada, las colecciones vacías")
    func empty() {
        #expect(text(HealthRecord()) == "{\n  \"version\": 1,\n  \"basculas\": [],\n  \"pesajes\": [],\n  \"cintura\": [],\n  \"nutricion\": []\n}")
    }

    @Test("lo escrito se lee igual")
    func roundTrip() {
        let record = HealthFixtures.record
        #expect(HealthRecordFormat.record(from: HealthRecordFormat.json(from: record)) == record)
    }

    @Test("la hora, con la diferencia con UTC de ese momento: verano, invierno y al oeste de UTC")
    func offsets() {
        let summer = HealthRecord(waist: [WaistMeasurement(id: "v", time: .instant(HealthFixtures.at(2026, 7, 1, 8, 5, 9, offset: 7200)), centimeters: 80)])
        #expect(text(summer).contains("\"en\": \"2026-07-01T08:05:09+02:00\""))
        let west = HealthRecord(waist: [WaistMeasurement(id: "w", time: .instant(HealthFixtures.at(2026, 1, 2, 23, 0, offset: -16200)), centimeters: 80)])
        #expect(text(west).contains("\"en\": \"2026-01-02T23:00:00-04:30\""))
        #expect(HealthRecordFormat.record(from: HealthRecordFormat.json(from: west)) == west)
    }

    @Test("lo que no es un salud.json de esta versión no se lee")
    func invalid() {
        #expect(HealthRecordFormat.record(from: Data("no".utf8)) == nil)
        #expect(HealthRecordFormat.record(from: Data(#"{"version":2,"basculas":[],"pesajes":[],"cintura":[],"nutricion":[]}"#.utf8)) == nil)
        #expect(HealthRecordFormat.record(from: Data(#"{"version":1,"basculas":[],"pesajes":[],"cintura":[]}"#.utf8)) == nil)
        #expect(HealthRecordFormat.record(from: Data(#"{"version":1,"basculas":[],"pesajes":[{"id":"p","en":"2026-11-01","bascula":"b"}],"cintura":[],"nutricion":[]}"#.utf8)) == nil,
                "Un momento sin hora no es un momento")
        #expect(HealthRecordFormat.record(from: Data(#"{"version":1,"basculas":[],"pesajes":[{"id":"p","fecha":"2026-11-01","bascula":"b","pesoKg":"73"}],"cintura":[],"nutricion":[]}"#.utf8)) == nil,
                "Un peso que no es un número")
    }
}
