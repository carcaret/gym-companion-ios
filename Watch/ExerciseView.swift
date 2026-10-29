import SwiftUI
import ViewModels

/// El ejercicio que se ve: el nombre y su posición, el plan de hoy y las sesiones de referencia (la
/// mejor reciente y, si es otra, la última). Saltado, atenuado salvo el «Saltado».
struct ExerciseView: View {
    let exercise: WatchModel.Exercise
    let isDimmed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(exercise.name)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 4)
                if !isDimmed {
                    Text(exercise.position)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            // Sin apagar: es lo que explica por qué lo demás sí lo está.
            if let status = exercise.status {
                Text(status)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.redSoft)
            }
            details
                .opacity(exercise.isSkipped ? 0.45 : 1)
        }
        .opacity(isDimmed ? 0.6 : 1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(exercise.plan)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.accentLight)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let best = exercise.best {
                ReferenceRow(reference: best, isPrimary: true)
            }
            if let last = exercise.last, !isDimmed {
                ReferenceRow(reference: last, isPrimary: false)
            }
            if let firstTime = exercise.firstTime {
                Text(firstTime)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

/// "Mejor 11·11·10·8 · 26 oct": la mejor, más visible que la última.
private struct ReferenceRow: View {
    let reference: WatchModel.Reference
    let isPrimary: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(reference.label)
                .foregroundStyle(Theme.textSecondary)
            Text(reference.detail)
                .foregroundStyle(isPrimary ? Theme.text : Theme.textSecondary)
                .fontWeight(isPrimary ? .semibold : .regular)
                .monospacedDigit()
            Text(reference.date)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .font(isPrimary ? .footnote : .caption2)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .combine)
    }
}
