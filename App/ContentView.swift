import HealthKit
import SwiftUI

struct ContentView: View {
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    private let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    @State private var result = "Sin leer"

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Prueba de HealthKit")
                .font(.largeTitle.bold())
            Text("Versión \(version) (\(build))")
                .foregroundStyle(.secondary)
            Button("Leer el peso") { Task { result = await readLatestBodyMass() } }
                .buttonStyle(.borderedProminent)
            Text(result)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func readLatestBodyMass() async -> String {
        guard HKHealthStore.isHealthDataAvailable() else { return "HealthKit no disponible" }
        let store = HKHealthStore()
        let bodyMass = HKQuantityType(.bodyMass)
        do {
            try await store.requestAuthorization(toShare: [], read: [bodyMass])
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: bodyMass)],
                sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                limit: 1
            )
            guard let sample = try await descriptor.result(for: store).first else {
                return "Permiso pedido; no hay peso registrado (o lectura denegada)"
            }
            let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
            return String(format: "%.1f kg (%@)", kg, sample.endDate.formatted(date: .abbreviated, time: .omitted))
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}
