import Presentation
import SwiftUI
import ViewModels

/// El ejercicio que se ve: el nombre y su posición, el peso de hoy con las reps de la mejor sesión
/// reciente (o, sin ninguna con ese peso, las objetivo) y, si es otra, las de la última (solo las
/// del peso de hoy). Saltado, atenuado salvo el
/// «Saltado». Con la muñeca bajada, todo atenuado y sin la posición; «Última» se queda, porque es lo
/// que toca hacer (decisión del usuario, 2026-10-31).
struct ExerciseView: View {
    let exercise: WatchModel.Exercise
    let isDimmed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                // Todo el ancho hasta la posición: con un `Spacer` en medio, el nombre saltaba de
                // línea antes de hacerle falta («Press Inclinado | en Máquina»).
                Text(exercise.name)
                    .font(.headline)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                .opacity(exercise.isSkipped ? Theme.skippedOpacity : 1)
        }
        .opacity(isDimmed ? Theme.wristDownOpacity : 1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            // "60 kg · 10·10·8": el peso en azul y las reps de la mejor (o las objetivo), que son
            // lo que se mira.
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(exercise.weight)
                    .foregroundStyle(Theme.accentLight)
                Text("·")
                    .foregroundStyle(Theme.textSecondary)
                Text(exercise.planReps)
                    .foregroundStyle(Theme.text)
            }
            .font(.body.weight(.semibold).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityElement(children: .combine)
            if let reps = exercise.lastReps {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(WatchText.last)
                        .foregroundStyle(Theme.textSecondary)
                    Text(reps)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .font(.footnote)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityElement(children: .combine)
            }
            if let firstTime = exercise.firstTime {
                Text(firstTime)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}
