import Domain
import Foundation

/// Traducción entre `HealthRecord` y el `salud.json` (#104): JSON con dos espacios, claves en
/// español y siempre en el mismo orden, para que lo mismo dé siempre los mismos bytes y los commits
/// solo muestren lo que cambia. Sin fecha de generación: la dice el commit, y si no, el fichero
/// cambiaría cada vez.
///
/// Un momento se escribe con su diferencia con UTC (`2026-11-01T09:27:38+01:00`); una medida de día
/// entero, solo con la fecha. En los pesajes y la cintura van en claves distintas (`en` o `fecha`);
/// en las básculas, en la misma (la primera y la última medida pueden ser de las dos clases).
public enum HealthRecordFormat {
    public static let version = 1

    public static func json(from record: HealthRecord) -> Data {
        Data(value(from: record).stringified().utf8)
    }

    /// `nil` si no es un `salud.json` de esta versión.
    public static func record(from json: Data) -> HealthRecord? {
        guard let root = JSONValue(parsing: json), root["version"] == .number(Double(version)),
              let scales = array(root["basculas"])?.map(scale), let weighings = array(root["pesajes"])?.map(weighing),
              let waist = array(root["cintura"])?.map(waistMeasurement), let nutrition = array(root["nutricion"])?.map(dailyNutrition),
              !scales.contains(nil), !weighings.contains(nil), !waist.contains(nil), !nutrition.contains(nil)
        else { return nil }
        return HealthRecord(scales: scales.compactMap { $0 }, weighings: weighings.compactMap { $0 }, waist: waist.compactMap { $0 },
                            nutrition: nutrition.compactMap { $0 })
    }

    // MARK: - Escribir

    private static func value(from record: HealthRecord) -> JSONValue {
        .object([
            ("version", .number(Double(version))),
            ("basculas", .array(record.scales.map(value))),
            ("pesajes", .array(record.weighings.map(value))),
            ("cintura", .array(record.waist.map(value))),
            ("nutricion", .array(record.nutrition.map(value))),
        ])
    }

    private static func value(_ scale: Scale) -> JSONValue {
        var members: [(key: String, value: JSONValue)] = [
            ("id", .string(scale.id)), ("nombre", .string(scale.source.name)), ("origen", .string(scale.source.bundleID)),
        ]
        if let device = scale.device {
            members.append(("aparato", .object(optional([("nombre", device.name.map(JSONValue.string)),
                                                         ("fabricante", device.manufacturer.map(JSONValue.string)),
                                                         ("modelo", device.model.map(JSONValue.string))]))))
        }
        members += [("primeraMedida", .string(text(scale.firstMeasurement))), ("ultimaMedida", .string(text(scale.lastMeasurement)))]
        return .object(members)
    }

    private static func value(_ weighing: Weighing) -> JSONValue {
        .object([("id", .string(weighing.id)), time(weighing.time), ("bascula", .string(weighing.scaleID))]
            + optional([("pesoKg", weighing.weightKg.map(JSONValue.number)), ("grasaPct", weighing.bodyFatPercent.map(JSONValue.number)),
                        ("magraKg", weighing.leanMassKg.map(JSONValue.number))]))
    }

    private static func value(_ waist: WaistMeasurement) -> JSONValue {
        .object([("id", .string(waist.id)), time(waist.time), ("cm", .number(waist.centimeters))])
    }

    private static func value(_ nutrition: DailyNutrition) -> JSONValue {
        .object([("fecha", .string(nutrition.date.iso)), ("origen", .string(nutrition.source))]
            + optional([("kcal", nutrition.kilocalories.map(JSONValue.number)), ("proteinaG", nutrition.proteinGrams.map(JSONValue.number)),
                        ("grasaG", nutrition.fatGrams.map(JSONValue.number)),
                        ("carbohidratosG", nutrition.carbohydrateGrams.map(JSONValue.number))]))
    }

    /// Lo que no hay no se escribe.
    private static func optional(_ members: [(String, JSONValue?)]) -> [(key: String, value: JSONValue)] {
        members.compactMap { key, value in value.map { (key, $0) } }
    }

    private static func time(_ time: MeasurementTime) -> (key: String, value: JSONValue) {
        switch time {
        case .instant: ("en", .string(text(time)))
        case .day: ("fecha", .string(text(time)))
        }
    }

    /// `2026-11-01T09:27:38+01:00` o `2025-07-04`.
    static func text(_ time: MeasurementTime) -> String {
        switch time {
        case .day(let day): return day.iso
        case .instant(let instant):
            let (hour, minute, second) = instant.localTime
            let offset = abs(instant.utcOffsetSeconds)
            let sign = instant.utcOffsetSeconds < 0 ? "-" : "+"
            return "\(instant.localDate.iso)T\(two(hour)):\(two(minute)):\(two(second))\(sign)\(two(offset / 3600)):\(two(offset % 3600 / 60))"
        }
    }

    private static func two(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    // MARK: - Leer

    private static func array(_ value: JSONValue?) -> [JSONValue]? {
        guard case .array(let items)? = value else { return nil }
        return items
    }

    private static func string(_ value: JSONValue?) -> String? {
        guard case .string(let text)? = value else { return nil }
        return text
    }

    /// Ausente es `nil`; presente y sin ser un número, inválido.
    private static func number(_ value: JSONValue?) -> Double?? {
        switch value {
        case nil: .some(nil)
        case .number(let number)?: .some(number)
        default: nil
        }
    }

    private static func scale(_ value: JSONValue) -> Scale? {
        guard let id = string(value["id"]), let name = string(value["nombre"]), let bundleID = string(value["origen"]),
              let first = string(value["primeraMedida"]).flatMap(time), let last = string(value["ultimaMedida"]).flatMap(time)
        else { return nil }
        let device = value["aparato"].map {
            HealthDevice(name: string($0["nombre"]), manufacturer: string($0["fabricante"]), model: string($0["modelo"]))
        }
        return Scale(id: id, source: HealthSource(bundleID: bundleID, name: name), device: device, firstMeasurement: first,
                     lastMeasurement: last)
    }

    private static func weighing(_ value: JSONValue) -> Weighing? {
        guard let id = string(value["id"]), let time = measurementTime(value), let scaleID = string(value["bascula"]),
              let weight = number(value["pesoKg"]), let fat = number(value["grasaPct"]), let lean = number(value["magraKg"])
        else { return nil }
        return Weighing(id: id, time: time, scaleID: scaleID, weightKg: weight, bodyFatPercent: fat, leanMassKg: lean)
    }

    private static func waistMeasurement(_ value: JSONValue) -> WaistMeasurement? {
        guard let id = string(value["id"]), let time = measurementTime(value), let centimeters = number(value["cm"]) ?? nil
        else { return nil }
        return WaistMeasurement(id: id, time: time, centimeters: centimeters)
    }

    private static func dailyNutrition(_ value: JSONValue) -> DailyNutrition? {
        guard let date = string(value["fecha"]).flatMap(LocalDate.init(iso:)), let source = string(value["origen"]),
              let kilocalories = number(value["kcal"]), let protein = number(value["proteinaG"]), let fat = number(value["grasaG"]),
              let carbohydrates = number(value["carbohidratosG"])
        else { return nil }
        return DailyNutrition(date: date, source: source, kilocalories: kilocalories, proteinGrams: protein, fatGrams: fat,
                              carbohydrateGrams: carbohydrates)
    }

    /// `en` (un momento) o `fecha` (un día entero).
    private static func measurementTime(_ value: JSONValue) -> MeasurementTime? {
        if let text = string(value["en"]) {
            guard case .instant(let instant)? = time(text) else { return nil }
            return .instant(instant)
        }
        return string(value["fecha"]).flatMap(LocalDate.init(iso:)).map(MeasurementTime.day)
    }

    /// Lee lo que escribe `text`.
    static func time(_ text: String) -> MeasurementTime? {
        if let day = LocalDate(iso: text) { return .day(day) }
        // 2026-11-01T09:27:38+01:00
        let characters = Array(text)
        guard characters.count == 25, characters[10] == "T", characters[13] == ":", characters[16] == ":", characters[22] == ":",
              let day = LocalDate(iso: String(characters[0..<10])), "+-".contains(characters[19]),
              let hour = Int(String(characters[11..<13])), let minute = Int(String(characters[14..<16])),
              let second = Int(String(characters[17..<19])), let offsetHours = Int(String(characters[20..<22])),
              let offsetMinutes = Int(String(characters[23..<25]))
        else { return nil }
        let offset = (characters[19] == "-" ? -1 : 1) * (offsetHours * 3600 + offsetMinutes * 60)
        return Instant(day, hour: hour, minute: minute, second: second, utcOffsetSeconds: offset).map(MeasurementTime.instant)
    }
}
