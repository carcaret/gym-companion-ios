import Domain
import Presentation
import SwiftUI
import ViewModels

/// Una tarjeta de ejercicio. En la vista previa y en el historial sin editar es de solo lectura;
/// en el entreno y al editar el historial, `actions` trae lo que se puede editar en ella
/// (cambiarla, saltarla y quitarla son gestos de la lista del entreno).
struct ExerciseCardView: View {
    let card: ExerciseCard
    let toggle: () -> Void
    var actions: CardActions?

    struct CardActions {
        let adjust: (LogParameter, Int) -> Void
        /// Lo que se va tecleando (`TypedValue`) y salir del campo, que lo aplica.
        let type: (LogParameter, String) -> Void
        let commit: () -> Void
        let focusSeries: (Int) -> Void
        let chooseRep: (Int, Int) -> Void
    }

    var body: some View {
        // El identificador, en el botón de la cabecera: puesto en toda la tarjeta pisaba el de cada
        // control de dentro (`weight-plus`, `series-0`…; `.xcresult` del CI, 2026-10-27).
        CardDisclosure(isExpanded: card.isOpen, identifier: "card-\(card.exerciseID.rawValue)", toggle: toggle) {
            header
        } content: {
            content
                .padding(.top, 14)
                // Saltada: el contenido se apaga para no competir (`.card.is-skipped` de la PWA).
                .saturation(card.isSkipped ? 0.15 : 1)
                .opacity(card.isSkipped ? 0.7 : 1)
        }
        .card(background: card.isSkipped ? Theme.skipTint : Theme.surface)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(card.title)
                    .scaledFont(15, .semibold)
                    .foregroundStyle(card.isSkipped ? Theme.textSecondary : Theme.text)
                if card.isVolumeRecord { RecordBadge(text: TodayText.volumeRecord) }
                if card.isE1RMRecord { RecordBadge(text: TodayText.e1rmRecord) }
            }
            // Lo cambiado al editar el historial, en amarillo de pendiente, como la nube, hasta la ✓
            // o la ✕.
            Text(card.subtitle)
                .scaledFont(12)
                .foregroundStyle(card.isDirty ? Theme.gold : Theme.textSecondary)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let strip = card.strip {
                HistoryStripView(strip: strip).padding(.bottom, 10)
                divider
            }
            // Sin hueco entre filas: cada zona de toque de 44 pt ya deja 8 pt entre los círculos de
            // una fila y los de la siguiente, sin montarse.
            VStack(spacing: 0) {
                parameterRow(.weight, TodayText.weightLabel, LogText.kilograms(card.weight), decimal: true, hasError: card.errors.contains(.negativeWeight))
                parameterRow(.series, TodayText.seriesLabel, "\(card.series)", decimal: false, hasError: card.errors.contains(.invalidSeries))
                parameterRow(.targetReps, TodayText.targetRepsLabel, "\(card.targetReps)", decimal: false, hasError: card.errors.contains(.invalidTargetReps))
            }
            .padding(.vertical, 10)
            divider
            VStack(alignment: .leading, spacing: 8) {
                Text(TodayText.seriesSectionLabel).sectionLabelStyle()
                HStack(spacing: 6) {
                    ForEach(Array(card.cells.enumerated()), id: \.offset) { series, cell in
                        SeriesCellView(cell: cell, index: series, targetReps: card.targetReps,
                                       onTap: actions.map { a in { a.focusSeries(series) } })
                    }
                }
                if !card.chips.isEmpty, let actions, let focused = card.cells.firstIndex(where: \.isFocused) {
                    HStack(spacing: 6) {
                        ForEach(card.chips, id: \.value) { chip in
                            Button("\(chip.value)") { actions.chooseRep(chip.value, focused) }
                                .buttonStyle(ChipButtonStyle(chip: chip))
                                .accessibilityIdentifier("chip-\(chip.value)")
                        }
                    }
                    // Los chips miden 44 de alto para el dedo y 32 a la vista: arriba y abajo no
                    // hace falta más margen.
                    .padding(.horizontal, 6)
                    .background(Theme.cardSolid, in: .rect(cornerRadius: 8))
                    .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.border) }
                }
            }
            .padding(.top, 10)
        }
    }

    private func parameterRow(_ parameter: LogParameter, _ label: String, _ value: String, decimal: Bool, hasError: Bool) -> some View {
        ParameterRow(parameter: parameter, label: label, value: value, decimal: decimal, hasError: hasError,
                     adjust: actions.map { a in { a.adjust(parameter, $0) } },
                     type: actions.map { a in { a.type(parameter, $0) } },
                     commit: actions?.commit)
    }

    private var divider: some View {
        Rectangle().fill(Theme.border).frame(height: 0.5)
    }
}
