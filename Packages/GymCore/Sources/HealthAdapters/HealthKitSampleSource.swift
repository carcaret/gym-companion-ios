#if canImport(HealthKit)
import Application
import Domain
import Foundation
import HealthKit

/// Las medidas del cuerpo y lo comido que hay en Salud (#104), todas, para el `salud.json`. La
/// primera vez pide permiso para leerlas (la hoja sale solo si falta alguno; con la app delante).
/// Sin permiso, Salud no da error: no enseña nada.
public struct HealthKitSampleSource: HealthSampleSource {
    public init() {}

    public func samples() async throws(HealthReadError) -> [HealthSample] {
        guard HKHealthStore.isHealthDataAvailable() else { throw .unavailable }
        let store = HKHealthStore()
        let quantities = HealthQuantity.allCases
        do {
            try await store.requestAuthorization(toShare: [], read: Set(quantities.map { Self.type(of: $0).type }))
            var samples: [HealthSample] = []
            for quantity in quantities {
                let (type, unit, scale) = Self.type(of: quantity)
                let found = try await HKSampleQueryDescriptor(predicates: [.quantitySample(type: type, predicate: nil)],
                                                              sortDescriptors: [SortDescriptor(\.startDate)]).result(for: store)
                samples += found.map { Self.sample($0, quantity: quantity, value: $0.quantity.doubleValue(for: unit) * scale) }
            }
            return samples
        } catch {
            throw .failed
        }
    }

    /// El tipo de Salud de cada medida, y cómo pasarlo a su unidad (`HealthQuantity`): el % de
    /// grasa, Salud lo da de 0 a 1.
    private static func type(of quantity: HealthQuantity) -> (type: HKQuantityType, unit: HKUnit, scale: Double) {
        switch quantity {
        case .bodyMass: (HKQuantityType(.bodyMass), .gramUnit(with: .kilo), 1)
        case .bodyFatPercentage: (HKQuantityType(.bodyFatPercentage), .percent(), 100)
        case .leanBodyMass: (HKQuantityType(.leanBodyMass), .gramUnit(with: .kilo), 1)
        case .waistCircumference: (HKQuantityType(.waistCircumference), .meterUnit(with: .centi), 1)
        case .dietaryEnergy: (HKQuantityType(.dietaryEnergyConsumed), .kilocalorie(), 1)
        case .protein: (HKQuantityType(.dietaryProtein), .gram(), 1)
        case .fat: (HKQuantityType(.dietaryFatTotal), .gram(), 1)
        case .carbohydrates: (HKQuantityType(.dietaryCarbohydrates), .gram(), 1)
        }
    }

    private static func sample(_ sample: HKQuantitySample, quantity: HealthQuantity, value: Double) -> HealthSample {
        // La zona horaria de la medida, si quien la escribió la dijo; si no, la del iPhone.
        let timeZone = (sample.metadata?[HKMetadataKeyTimeZone] as? String).flatMap(TimeZone.init(identifier:)) ?? .current
        let source = sample.sourceRevision.source
        return HealthSample(
            id: sample.uuid.uuidString,
            quantity: quantity,
            value: value,
            start: instant(sample.startDate, in: timeZone),
            end: instant(sample.endDate, in: timeZone),
            source: HealthSource(bundleID: source.bundleIdentifier, name: source.name),
            device: sample.device.map { HealthDevice(name: $0.name, manufacturer: $0.manufacturer, model: $0.model) }
        )
    }

    private static func instant(_ date: Date, in timeZone: TimeZone) -> Instant {
        Instant(secondsSinceEpoch: Int(date.timeIntervalSince1970.rounded(.down)), utcOffsetSeconds: timeZone.secondsFromGMT(for: date))
    }
}
#endif
