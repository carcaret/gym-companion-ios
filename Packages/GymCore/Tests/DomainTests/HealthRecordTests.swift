import Domain
import Testing

// Lo que se guarda de Salud en el `salud.json` (#104): pesajes atados a su báscula, cintura y
// nutrición por día, tal cual y siempre en el mismo orden.

private let spain = 3600
private let fitdays = HealthSource(bundleID: "com.fitdays.fitdays", name: "Fitdays")
private let macroFactor = HealthSource(bundleID: "com.sbs.diet", name: "MacroFactor")

private func at(_ day: String, _ hour: Int, _ minute: Int, _ second: Int = 0, offset: Int = spain) -> Instant {
    Instant(LocalDate(day), hour: hour, minute: minute, second: second, utcOffsetSeconds: offset)!
}

private func sample(_ id: String, _ quantity: HealthQuantity, _ value: Double, _ start: Instant, end: Instant? = nil,
                    source: HealthSource = fitdays, device: HealthDevice? = nil) -> HealthSample {
    HealthSample(id: id, quantity: quantity, value: value, start: start, end: end, source: source, device: device)
}

@Suite("Instant: el momento de una medida en hora local")
struct InstantTests {
    @Test("el día y la hora locales salen de la diferencia con UTC")
    func local() {
        let instant = at("2026-11-01", 9, 27, 38)
        #expect(instant.localDate == "2026-11-01")
        #expect([instant.localTime.hour, instant.localTime.minute, instant.localTime.second] == [9, 27, 38])
        #expect(instant.secondsSinceEpoch == at("2026-11-01", 8, 27, 38, offset: 0).secondsSinceEpoch)
    }

    @Test("a las 0:30 en España aún es el día anterior en UTC, pero el día local es el de España")
    func crossesMidnight() {
        let instant = at("2026-11-01", 0, 30)
        #expect(instant.localDate == "2026-11-01")
        #expect(Instant(secondsSinceEpoch: instant.secondsSinceEpoch, utcOffsetSeconds: 0).localDate == "2026-10-31")
    }

    @Test("antes de 1970 el día también es el bueno")
    func beforeEpoch() {
        #expect(at("1969-12-31", 23, 0, offset: 0).localDate == "1969-12-31")
        #expect(at("1969-12-31", 23, 0, offset: 0).localTime.hour == 23)
    }

    @Test("una hora que no existe no es un momento")
    func invalid() {
        #expect(Instant(LocalDate("2026-11-01"), hour: 24, minute: 0, utcOffsetSeconds: 0) == nil)
        #expect(Instant(LocalDate("2026-11-01"), hour: 9, minute: 60, utcOffsetSeconds: 0) == nil)
    }
}

@Suite("MeasurementTime: un momento o un día entero")
struct MeasurementTimeTests {
    @Test("si empieza y acaba a la vez es un momento; si no, el día en que empieza")
    func fromInterval() {
        let start = at("2025-07-04", 0, 0)
        #expect(MeasurementTime(start: start, end: start) == .instant(start))
        #expect(MeasurementTime(start: start, end: at("2025-07-04", 23, 59, 59)) == .day("2025-07-04"))
    }

    @Test("por días, y el día entero antes que los momentos de ese día")
    func order() {
        let times: [MeasurementTime] = [.instant(at("2026-11-01", 9, 0)), .day("2026-11-01"), .instant(at("2026-10-31", 23, 0)),
                                        .day("2026-10-30")]
        #expect(times.sorted() == [.day("2026-10-30"), .instant(at("2026-10-31", 23, 0)), .day("2026-11-01"),
                                   .instant(at("2026-11-01", 9, 0))])
    }
}

@Suite("HealthRecord: lo que se guarda de Salud")
struct HealthRecordTests {
    @Test("peso, % de grasa y masa sin grasa del mismo momento y la misma app son un pesaje, que se llama como su peso")
    func groupsWeighing() {
        let time = at("2026-11-01", 9, 27, 38)
        let record = HealthRecord(samples: [
            sample("grasa", .bodyFatPercentage, 19.8, time),
            sample("peso", .bodyMass, 73.3, time),
            sample("magra", .leanBodyMass, 58.79, time),
        ])
        #expect(record.weighings == [Weighing(id: "peso", time: .instant(time), scaleID: "com.fitdays.fitdays", weightKg: 73.3,
                                              bodyFatPercent: 19.8, leanMassKg: 58.79)])
    }

    @Test("dos pesos en el mismo momento son dos pesajes")
    func repeatedQuantity() {
        let time = at("2026-11-01", 9, 0)
        let record = HealthRecord(samples: [sample("a", .bodyMass, 73.3, time), sample("b", .bodyMass, 73.4, time),
                                            sample("c", .bodyFatPercentage, 19.8, time)])
        #expect(record.weighings.map(\.id) == ["a", "b"])
        #expect(record.weighings.map(\.bodyFatPercent) == [19.8, nil])
    }

    @Test("medidas de momentos distintos, o de apps distintas, no se juntan")
    func separateWeighings() {
        let record = HealthRecord(samples: [
            sample("peso", .bodyMass, 73.3, at("2026-11-01", 9, 0)),
            sample("grasa", .bodyFatPercentage, 19.8, at("2026-11-01", 9, 1)),
            sample("otra", .bodyMass, 73.2, at("2026-11-01", 9, 0), source: macroFactor),
        ])
        #expect(record.weighings.count == 3)
        #expect(record.weighings.first { $0.id == "grasa" }?.weightKg == nil)
    }

    @Test("un peso de día entero (MacroFactor) va con su fecha y sin hora")
    func daySample() {
        let record = HealthRecord(samples: [sample("mf", .bodyMass, 72.8, at("2025-07-04", 0, 0), end: at("2025-07-04", 23, 59, 59),
                                                   source: macroFactor)])
        #expect(record.weighings == [Weighing(id: "mf", time: .day("2025-07-04"), scaleID: "com.sbs.diet", weightKg: 72.8)])
    }

    @Test("cada app es una báscula, con su primera y su última medida, por orden de la primera")
    func scales() {
        let record = HealthRecord(samples: [
            sample("f2", .bodyMass, 73.3, at("2026-11-01", 9, 0)),
            sample("f1", .bodyMass, 75.1, at("2025-09-01", 8, 0)),
            sample("m1", .bodyMass, 72.8, at("2025-07-04", 0, 0), end: at("2025-07-04", 23, 59, 59), source: macroFactor),
        ])
        #expect(record.scales == [
            Scale(id: "com.sbs.diet", source: macroFactor, device: nil, firstMeasurement: .day("2025-07-04"), lastMeasurement: .day("2025-07-04")),
            Scale(id: "com.fitdays.fitdays", source: fitdays, device: nil, firstMeasurement: .instant(at("2025-09-01", 8, 0)),
                  lastMeasurement: .instant(at("2026-11-01", 9, 0))),
        ])
        #expect(record.weighings.map(\.scaleID) == ["com.sbs.diet", "com.fitdays.fitdays", "com.fitdays.fitdays"])
    }

    @Test("con aparato, la báscula es la app y el aparato: dos aparatos con la misma app son dos básculas")
    func device() {
        let old = HealthDevice(name: "Báscula", manufacturer: "Healthkeep", model: "FG2016LB")
        let new = HealthDevice(name: "Báscula nueva")
        let record = HealthRecord(samples: [
            sample("a", .bodyMass, 73.3, at("2026-11-01", 9, 0), device: old),
            sample("b", .bodyMass, 73.1, at("2026-11-02", 9, 0), device: new),
            sample("c", .bodyMass, 73.0, at("2026-11-03", 9, 0), device: HealthDevice()),
        ])
        #expect(record.scales.map(\.id) == ["com.fitdays.fitdays#FG2016LB", "com.fitdays.fitdays#Báscula nueva", "com.fitdays.fitdays"])
        #expect(record.scales.first?.device == old)
        #expect(record.scales.last?.device == nil, "Un aparato sin datos no es un aparato")
    }

    @Test("la cintura, cada medida con un decimal, sin báscula")
    func waist() {
        let record = HealthRecord(samples: [sample("c", .waistCircumference, 82.54, at("2026-10-20", 8, 15))])
        #expect(record.waist == [WaistMeasurement(id: "c", time: .instant(at("2026-10-20", 8, 15)), centimeters: 82.5)])
        #expect(record.scales.isEmpty)
        #expect(record.weighings.isEmpty)
    }

    @Test("la nutrición, sumada por día local y app, redondeada")
    func nutrition() {
        let record = HealthRecord(samples: [
            sample("1", .dietaryEnergy, 800.4, at("2026-10-31", 9, 0), source: macroFactor),
            sample("2", .dietaryEnergy, 1730.3, at("2026-10-31", 21, 0), source: macroFactor),
            sample("3", .protein, 60.04, at("2026-10-31", 9, 0), source: macroFactor),
            sample("4", .protein, 100.02, at("2026-10-31", 21, 0), source: macroFactor),
            sample("5", .dietaryEnergy, 500, at("2026-11-01", 0, 30), source: macroFactor),
            sample("6", .dietaryEnergy, 200, at("2026-10-31", 12, 0), source: fitdays),
        ])
        #expect(record.nutrition == [
            DailyNutrition(date: "2026-10-31", source: "Fitdays", kilocalories: 200),
            DailyNutrition(date: "2026-10-31", source: "MacroFactor", kilocalories: 2531, proteinGrams: 160.1),
            DailyNutrition(date: "2026-11-01", source: "MacroFactor", kilocalories: 500),
        ])
    }

    @Test("kg y % con dos decimales: el ruido de los decimales no cambia el fichero")
    func rounding() {
        let time = at("2026-11-01", 9, 0)
        let record = HealthRecord(samples: [sample("p", .bodyMass, 73.30000000001, time), sample("g", .bodyFatPercentage, 19.799999, time)])
        #expect(record.weighings.first?.weightKg == 73.3)
        #expect(record.weighings.first?.bodyFatPercent == 19.8)
    }

    @Test("lo mismo en otro orden da lo mismo, ordenado por fecha")
    func deterministic() {
        let samples = [
            sample("b", .bodyMass, 73.3, at("2026-11-01", 9, 0)),
            sample("a", .bodyMass, 73.0, at("2026-10-01", 9, 0)),
            sample("c", .waistCircumference, 82, at("2026-11-01", 9, 0)),
            sample("d", .waistCircumference, 83, at("2026-10-01", 9, 0)),
        ]
        let record = HealthRecord(samples: samples)
        #expect(HealthRecord(samples: samples.reversed()) == record)
        #expect(record.weighings.map(\.id) == ["a", "b"])
        #expect(record.waist.map(\.id) == ["d", "c"])
    }

    @Test("sin medidas está vacío; el resumen cuenta pesajes, medidas de cintura y días con comida")
    func summary() {
        #expect(HealthRecord(samples: []).isEmpty)
        let record = HealthRecord(samples: [
            sample("p", .bodyMass, 73.3, at("2026-11-01", 9, 0)),
            sample("c", .waistCircumference, 82, at("2026-11-01", 9, 0)),
            sample("k", .dietaryEnergy, 2500, at("2026-10-31", 9, 0), source: macroFactor),
            sample("q", .protein, 160, at("2026-10-31", 9, 0), source: macroFactor),
            sample("f", .dietaryEnergy, 100, at("2026-10-31", 9, 0)),
        ])
        #expect(!record.isEmpty)
        #expect(record.summary == HealthRecord.Summary(weighings: 1, waistMeasurements: 1, nutritionDays: 1))
    }
}
