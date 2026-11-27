import Domain
import Presentation
import SwiftUI
import ViewModels

/// Un ejercicio (`.stats-row`), una fila de la lista: a la izquierda, el icono de su estado (como
/// los de Ajustes): azul y flecha si progresa, dorado e igual si está estancado, gris sin recorrido.
/// En los estancados, debajo de la frase, qué cambió desde el récord. Al abrirla, sus últimas
/// sesiones, una por línea con su día, cómo estaba hace 3 meses y «Ver en Gráficas».
struct ExerciseProgressRow: View {
    let row: ProgressModel.ExerciseRow
    let toggle: () -> Void
    let openCharts: () -> Void
    @ScaledMetric(relativeTo: .subheadline) private var iconSide: CGFloat = 28

    var body: some View {
        CardDisclosure(isExpanded: row.isOpen, chevronSize: 12, identifier: AccessibilityID.statsRow(row.exerciseID.rawValue),
                       headerPadding: EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16), toggle: toggle) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .scaledFont(13, .bold)
                    .foregroundStyle(noTrack ? Theme.text : Theme.background)
                    .frame(width: iconSide, height: iconSide)
                    .background(color, in: .rect(cornerRadius: 7))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.name).scaledFont(15, .medium).foregroundStyle(noTrack ? Theme.textSecondary : Theme.text)
                        Spacer()
                        if let weight = row.weight {
                            // En gris sin recorrido, como el nombre: no es un dato que mirar.
                            Text(weight).scaledFont(14, .semibold).foregroundStyle(noTrack ? Theme.textSecondary : Theme.accentLight)
                        }
                    }
                    Text(row.phrase).scaledFont(12).foregroundStyle(Theme.textSecondary)
                    if let setsChange = row.setsChange {
                        // Más clara que la frase: es el dato nuevo (#112).
                        Text(setsChange).scaledFont(12).foregroundStyle(Theme.text)
                    }
                }
            }
            .padding(.vertical, 4)
        } content: {
            // Alineado con el nombre, a la derecha del icono. El botón llega a los dos bordes de la
            // sección, con el margen dentro: se toca toda su fila.
            VStack(alignment: .leading, spacing: 6) {
                Group {
                    Text(ProgressText.recentSessions).sectionLabelStyle()
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3) {
                        ForEach(Array(row.recentSessions.enumerated()), id: \.offset) { _, session in
                            GridRow {
                                Text(session.date).foregroundStyle(Theme.textSecondary)
                                Text(session.reps).foregroundStyle(noTrack ? Theme.textSecondary : Theme.text)
                            }
                        }
                    }
                    .scaledFont(13).monospacedDigit()
                    if let lookBack = row.lookBack {
                        lookBackBox(lookBack)
                    }
                }
                .padding(.leading, indent)
                .padding(.trailing, 16)
                if row.canOpenCharts {
                    Button(action: openCharts) {
                        Text(ProgressText.openCharts)
                            .scaledFont(15)
                            .foregroundStyle(Theme.accentLight)
                            .frame(maxWidth: .infinity, minHeight: TouchTarget.minimum, alignment: .leading)
                            .padding(.leading, indent)
                            .padding(.trailing, 16)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
        }
    }

    /// Cómo estaba hace 3 meses, en un recuadro azul suave para que se distinga de las últimas
    /// sesiones; la fila, con el formato de su rejilla (#112).
    private func lookBackBox(_ lookBack: ProgressModel.LookBackRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ProgressText.lookBackTitle).sectionLabelStyle()
            HStack(spacing: 12) {
                Text(lookBack.date).foregroundStyle(Theme.textSecondary)
                Text(lookBack.detail).foregroundStyle(noTrack ? Theme.textSecondary : Theme.text)
            }
            .scaledFont(13).monospacedDigit()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accentTint, in: .rect(cornerRadius: 10))
        .padding(.top, 6)
    }

    /// El margen de la sección y el icono con su hueco.
    private var indent: CGFloat { 16 + iconSide + 12 }

    private var noTrack: Bool { row.status == .noTrack }

    private var symbol: String {
        switch row.status {
        case .progressing: "arrow.up.right"
        case .stalled: "equal"
        case .noTrack: "minus"
        }
    }

    private var color: Color {
        switch row.status {
        case .progressing: Theme.accent
        case .stalled: Theme.gold
        case .noTrack: Theme.borderStrong
        }
    }
}
