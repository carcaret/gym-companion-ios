import Domain
import Presentation
import SwiftUI
import ViewModels

/// El mes en la lista, con el aspecto de la cabecera de sección que era: se va al desplazar.
struct MonthHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .scaledFont(17, .semibold)
            .foregroundStyle(Theme.textSecondary)
            .accessibilityAddTraits(.isHeader)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 18, leading: 16, bottom: 4, trailing: 16))
    }
}

/// Una sesión (`.historial-entry-btn`): la fecha en bloque, la etiqueta de la rutina con su color,
/// "hace…" y los ejercicios, con el filete del día. Sin terminar, con el tinte azul.
struct HistoryRowView: View {
    let row: HistoryModel.Row

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(row.day).scaledFont(20, .bold).monospacedDigit().foregroundStyle(Theme.text)
                Text(row.month).scaledFont(11, .semibold).tracking(0.4).foregroundStyle(Theme.textSecondary)
            }
            .frame(minWidth: 40)
            Rectangle().fill(Theme.border).frame(width: 1, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    RoutineBadge(text: row.routine, color: Theme.color(row.tint) ?? Theme.textSecondary)
                    if let relative = row.relative {
                        Text(relative).scaledFont(11).foregroundStyle(Theme.textSecondary)
                    }
                    if row.isIncomplete {
                        Image(systemName: "pause.fill").scaledFont(11).foregroundStyle(Theme.accent).accessibilityLabel(HistoryText.incomplete)
                    }
                }
                Text(row.summary).scaledFont(12).foregroundStyle(Theme.textSecondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .card(background: row.isIncomplete ? Theme.accent.opacity(0.07) : Theme.surface,
              border: row.isIncomplete ? Theme.accent.opacity(0.35) : nil,
              stripe: Theme.color(row.tint))
        .contentShape(.rect)
    }
}

/// La etiqueta de una rutina (`.type-badge`): mayúsculas pequeñas en su color, sobre su color suave.
struct RoutineBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .scaledFont(11, .bold)
            .textCase(.uppercase)
            .tracking(0.4)
            .lineLimit(1)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.13), in: .rect(cornerRadius: Theme.radiusTag))
            .overlay { RoundedRectangle(cornerRadius: Theme.radiusTag).strokeBorder(color.opacity(0.27)) }
    }
}
