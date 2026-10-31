import Presentation
import SwiftUI
import ViewModels

/// El entreno terminado y guardado en Salud: tiempo, kcal y pulso medio.
struct SummaryView: View {
    let summary: WatchModel.Summary
    let done: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(WatchText.finished)
                        .font(.headline)
                    Text(WatchText.activity)
                        .font(.footnote)
                        .foregroundStyle(Theme.accentLight)
                }
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                    GridRow {
                        value(WatchText.duration, summary.duration, color: Theme.gold)
                        value(WatchText.activeEnergy, summary.activeEnergy, color: Theme.text)
                    }
                    GridRow {
                        value(WatchText.averageHeartRate, summary.averageHeartRate, color: Theme.redSoft)
                        value(WatchText.totalEnergy, summary.totalEnergy, color: Theme.text)
                    }
                }
                Label(WatchText.savedToHealth, systemImage: "checkmark")
                    .font(.footnote)
                    .foregroundStyle(Theme.greenSoft)
                Button(WatchText.done, action: done)
                    .accessibilityIdentifier(AccessibilityID.watchDone)
                    .centeredInRow()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func value(_ label: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
    }
}
