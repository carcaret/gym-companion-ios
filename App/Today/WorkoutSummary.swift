import Domain
import Presentation
import SwiftUI
import ViewModels

/// El entreno terminado, empujado sobre el selector: se vuelve a las rutinas con la flecha de la
/// barra, deslizando desde el borde o tocando otra vez la pestaña (decisión del usuario,
/// 2026-10-27; antes no tenía ninguna forma de salir salvo la pestaña).
struct WorkoutSummary: View {
    @Bindable var model: TodayModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Label(TodayText.completedStatus, systemImage: "checkmark.circle.fill")
                    .accessibilityIdentifier("workout-completed")
                    .scaledFont(14, .medium)
                    .foregroundStyle(Theme.text)
                    .symbolRenderingMode(.multicolor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.greenTint, in: .rect(cornerRadius: Theme.radiusSmall))
                    .overlay { RoundedRectangle(cornerRadius: Theme.radiusSmall).strokeBorder(Theme.greenSoft.opacity(0.3)) }
                ForEach(Array(model.completedRows.enumerated()), id: \.offset) { _, row in
                    SummaryRowView(title: row.title, subtitle: row.subtitle, isSkipped: row.isSkipped)
                }
            }
            .padding(16)
        }
    }
}

/// Una línea de un entreno terminado: una tarjeta compacta; la de un ejercicio saltado, con el tinte
/// rojo apagado de la PWA.
private struct SummaryRowView: View {
    let title: String
    let subtitle: String
    let isSkipped: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).scaledFont(15, .semibold).foregroundStyle(isSkipped ? Theme.textSecondary : Theme.text)
            Text(subtitle).scaledFont(12).foregroundStyle(Theme.textSecondary)
        }
        .card(background: isSkipped ? Theme.skipTint : Theme.surface)
    }
}
