import Presentation
import SwiftUI
import ViewModels

/// La página de la izquierda mientras se mide: el pulso y las kcal, y «Terminar».
struct ControlsPage: View {
    let model: WatchModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                metric(model.metrics.heartRate, unit: WatchText.heartRateUnit, color: Theme.redSoft)
                metric(model.metrics.activeEnergy, unit: WatchText.activeEnergyUnit, color: Theme.text)
                metric(model.metrics.totalEnergy, unit: WatchText.totalEnergyUnit, color: Theme.text)
                Button(role: .destructive) {
                    Task { await model.finish() }
                } label: {
                    Label(WatchText.finish, systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier(AccessibilityID.watchFinish)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func metric(_ value: String, unit: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
            Text(unit)
                .font(.caption2)
        }
        .foregroundStyle(color)
        .accessibilityElement(children: .combine)
    }
}
