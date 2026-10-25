import Domain
import Presentation
import SwiftUI
import ViewModels

/// Una tarjeta de ejercicio. En la vista previa es de solo lectura; en el entreno, `actions` trae
/// lo que se puede hacer con ella.
struct ExerciseCardView: View {
    let card: ExerciseCard
    let toggle: () -> Void
    var actions: CardActions?
    /// Historial: "Guardar" cuando hay cambios.
    var save: (() -> Void)?

    struct CardActions {
        let adjust: (LogParameter, Int) -> Void
        /// Lo que se va tecleando (`TypedValue`) y salir del campo, que lo aplica.
        let type: (LogParameter, String) -> Void
        let commit: () -> Void
        let focusSeries: (Int) -> Void
        let chooseRep: (Int, Int) -> Void
        /// Solo en el entreno (en el historial no se cambia, salta ni quita).
        let swap: (() -> Void)?
        let toggleSkip: (() -> Void)?
        let remove: (() -> Void)?
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if card.isOpen {
                content
                    .padding(.top, 14)
                    // Saltada: el contenido se apaga para no competir (`.card.is-skipped` de la PWA).
                    .saturation(card.isSkipped ? 0.15 : 1)
                    .opacity(card.isSkipped ? 0.7 : 1)
                footer
            }
        }
        .card(background: card.isSkipped ? Theme.skipTint : Theme.surface)
        .accessibilityIdentifier("card-\(card.exerciseID.rawValue)")
    }

    private var header: some View {
        Button(action: toggle) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(card.title)
                            .font(.scaled(15, weight: .semibold))
                            .foregroundStyle(card.isSkipped ? Theme.textMuted : Theme.text)
                        if card.isVolumeRecord { RecordBadge(text: TodayText.volumeRecord) }
                        if card.isE1RMRecord { RecordBadge(text: TodayText.e1rmRecord) }
                    }
                    Text(card.subtitle)
                        .font(.scaled(12))
                        .foregroundStyle(card.isSkipped ? Theme.textMuted : Theme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.scaled(13, weight: .semibold))
                    .rotationEffect(.degrees(card.isOpen ? 180 : 0))
                    .foregroundStyle(Theme.textMuted)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(card.isOpen ? .isSelected : [])
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let strip = card.strip {
                HistoryStripView(strip: strip).padding(.bottom, 10)
                divider
            }
            VStack(spacing: 8) {
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
                        SeriesCellView(cell: cell, onTap: actions.map { a in { a.focusSeries(series) } })
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
                    .padding(6)
                    .background(Theme.cardSolid, in: .rect(cornerRadius: 8))
                    .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.border) }
                }
            }
            .padding(.top, 10)
        }
    }

    private func parameterRow(_ parameter: LogParameter, _ label: String, _ value: String, decimal: Bool, hasError: Bool) -> some View {
        ParameterRow(label: label, value: value, decimal: decimal, hasError: hasError,
                     adjust: actions.map { a in { a.adjust(parameter, $0) } },
                     type: actions.map { a in { a.type(parameter, $0) } },
                     commit: actions?.commit)
    }

    @ViewBuilder
    private var footer: some View {
        if card.isEditable, let actions, let swap = actions.swap, let toggleSkip = actions.toggleSkip, let remove = actions.remove {
            HStack {
                footerButton(TodayText.swapLabel, action: swap)
                Spacer()
                footerButton(card.skipLabel, action: toggleSkip)
                    .foregroundStyle(card.isSkipped ? Theme.redSoft : Theme.textMuted)
                footerButton(card.removeLabel, role: .destructive, action: remove)
                    .padding(.leading, 12)
            }
            .font(.scaled(12))
            .foregroundStyle(Theme.textMuted)
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        if card.isDirty, let save {
            Button(action: save) { Text(HistoryText.save).frame(maxWidth: .infinity) }
                .buttonStyle(.pill())
                .accessibilityIdentifier("history-save")
                .padding(.top, 14)
        }
    }

    /// Texto pequeño como en la PWA, pero con la zona de toque de 44 pt que pide iOS.
    private func footerButton(_ title: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Text(title).frame(minHeight: 44).contentShape(.rect)
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.border).frame(height: 0.5)
    }
}

/// Récord: dorado sobre dorado muy suave (`.record-badge`).
private struct RecordBadge: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "trophy.fill")
            .font(.scaled(11, weight: .bold))
            .foregroundStyle(Theme.gold)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Theme.gold.opacity(0.1), in: .capsule)
    }
}

/// Peso, series u objetivo: −/+ redondos y el valor, que se puede teclear (en la vista previa,
/// solo el valor).
private struct ParameterRow: View {
    let label: String
    let value: String
    let decimal: Bool
    let hasError: Bool
    let adjust: ((Int) -> Void)?
    let type: ((String) -> Void)?
    let commit: (() -> Void)?
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(label).font(.scaled(12, weight: .medium)).foregroundStyle(Theme.textSecondary)
            Spacer()
            if let adjust, let type, let commit {
                RoundIconButton(systemImage: "minus") { adjust(-1) }
                TextField(label, text: $text)
                    .keyboardType(decimal ? .decimalPad : .numberPad)
                    .multilineTextAlignment(.center)
                    .font(.scaled(15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 72, height: 36)
                    .background(Theme.input, in: .rect(cornerRadius: 7))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7).strokeBorder(hasError ? Theme.red : focused ? Theme.accent : Theme.border)
                    }
                    .focused($focused)
                    .onAppear { text = value }
                    .onChange(of: value) { _, new in text = new }
                    // Un botón no quita el foco: el modelo se queda con lo tecleado y lo aplica
                    // al salir del campo o antes de la siguiente acción (`TypedValue`).
                    .onChange(of: text) { _, new in if focused, new != value { type(new) } }
                    .onChange(of: focused) { _, isFocused in if !isFocused { commit() } }
                    .onDisappear { if focused { commit() } }
                RoundIconButton(systemImage: "plus") { adjust(1) }
            } else {
                Text(value)
                    .font(.scaled(15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 72, height: 36)
                    .background(Theme.input, in: .rect(cornerRadius: 7))
                    .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.border) }
            }
        }
    }
}

/// `.btn-icon`: botón redondo con borde.
private struct RoundIconButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.scaled(14, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 36, height: 36)
                .background(Theme.input, in: .circle)
                .overlay { Circle().strokeBorder(Theme.border) }
        }
        .buttonStyle(.plain)
    }
}

/// Una celda de serie: azul si llega al objetivo, verde si se queda corta, dorada la que se edita
/// y roja con error (`.series-cell-chip`).
private struct SeriesCellView: View {
    let cell: ExerciseCard.SeriesCell
    let onTap: (() -> Void)?

    var body: some View {
        VStack(spacing: 3) {
            Text(cell.label).font(.scaled(10)).foregroundStyle(Theme.textMuted)
            if let onTap {
                Button(action: onTap) { valueText }
                    .buttonStyle(.plain)
            } else {
                valueText
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var valueText: some View {
        Text(cell.text)
            .font(.scaled(13, weight: .semibold))
            .foregroundStyle(colors.text)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(colors.background, in: .rect(cornerRadius: Theme.radiusTag))
            .overlay { RoundedRectangle(cornerRadius: Theme.radiusTag).strokeBorder(colors.border) }
    }

    private var colors: (text: Color, background: Color, border: Color) {
        if cell.hasError { return (Color(hex: 0xFFA9A9), Theme.dangerTint, Theme.danger) }
        if cell.isFocused { return (Theme.focus, Theme.focus.opacity(0.12), Theme.focus) }
        switch cell.state {
        case .done: return (Theme.accentSoft, Theme.accentTint, Theme.accent.opacity(0.5))
        case .filled: return (Theme.greenSoft, Theme.greenTint, Theme.greenSoft.opacity(0.5))
        case .empty: return (Theme.text, Theme.input, Theme.border)
        }
    }
}

/// Un chip de reps (`.chip-strip .chip`): verde por debajo del objetivo, azul en el objetivo y
/// rojo por encima; el elegido, relleno.
private struct ChipButtonStyle: ButtonStyle {
    let chip: ExerciseCard.Chip

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.scaled(13, weight: .semibold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: 32)
            .background(chip.isCurrent ? color.opacity(0.15) : .clear, in: .rect(cornerRadius: Theme.radiusTag))
            .overlay { RoundedRectangle(cornerRadius: Theme.radiusTag).strokeBorder(chip.isCurrent ? color : color.opacity(0.3)) }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }

    private var color: Color {
        switch chip.relation {
        case .below: Theme.greenSoft
        case .atTarget: Theme.accentSoft
        case .above: Theme.danger
        }
    }
}
