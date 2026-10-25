import SwiftUI
import ViewModels

/// Un ejercicio en el Apple Watch Series 10 de 46 mm: arriba, lo de hoy (peso y reps) en grande;
/// debajo, las reps de las sesiones anteriores, una por fila.
struct ExercisePageView: View {
    let page: WatchModel.Page

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(page.name)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 4)
                Text(page.position)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(page.weight)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.accentLight)
            Text(page.reps)
                .font(.title2.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Divider()
                .padding(.vertical, 4)
            if let noPrevious = page.noPrevious {
                Text(noPrevious)
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
            }
            ForEach(page.previous.indices, id: \.self) { index in
                let row = page.previous[index]
                HStack(spacing: 8) {
                    Text(row.date)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 56, alignment: .leading)
                    Text(row.reps)
                        .monospacedDigit()
                }
                .font(.body)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Sin tocar los puntos de página que watchOS pinta a la derecha.
        .padding(.trailing, 14)
        .opacity(page.isSkipped ? 0.45 : 1)
    }
}
