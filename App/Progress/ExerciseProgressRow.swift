import Charts
import Domain
import Presentation
import SwiftUI
import ViewModels

/// Un ejercicio (`.stats-row`), una fila de la lista: a la izquierda, el icono de su estado (como
/// los de Ajustes): azul y flecha si progresa, dorado e igual si está estancado, gris sin recorrido.
/// Al abrirla, sus últimas sesiones y «Ver en Gráficas».
struct ExerciseProgressRow: View {
    let row: ProgressModel.ExerciseRow
    let toggle: () -> Void
    let openCharts: () -> Void
    @ScaledMetric(relativeTo: .subheadline) private var iconSide: CGFloat = 28

    var body: some View {
        CardDisclosure(isExpanded: row.isOpen, chevronSize: 12, identifier: "stats-row-\(row.exerciseID.rawValue)",
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
                            Text(weight).scaledFont(14, .semibold).foregroundStyle(Theme.accentLight)
                        }
                    }
                    Text(row.phrase).scaledFont(12).foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.vertical, 4)
        } content: {
            // Alineado con el nombre, a la derecha del icono. El botón llega a los dos bordes de la
            // sección, con el margen dentro: se toca toda su fila.
            VStack(alignment: .leading, spacing: 6) {
                Group {
                    Text(ProgressText.recentSessions).sectionLabelStyle()
                    Text(row.recentReps.joined(separator: "  ·  "))
                        .scaledFont(13).monospacedDigit()
                        .foregroundStyle(noTrack ? Theme.textSecondary : Theme.text)
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
