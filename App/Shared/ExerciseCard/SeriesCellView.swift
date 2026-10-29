import Domain
import Presentation
import SwiftUI
import ViewModels

/// Una celda de serie: azul si llega al objetivo, naranja si se queda corta y roja con error
/// (`.series-cell-chip`; en la PWA, corta era verde). La que se edita conserva su color y lleva un
/// borde claro más grueso: la selección no es un color más (repaso de la HIG, 2026-10-28; antes,
/// dorada, el amarillo de pendiente y del récord, junto al naranja de corta).
struct SeriesCellView: View {
    let cell: ExerciseCard.SeriesCell
    let index: Int
    let targetReps: Int
    let onTap: (() -> Void)?

    var body: some View {
        // Se toca la celda entera, con su «S1»: así la zona de toque pasa de 44 pt sin que la
        // celda crezca.
        Group {
            if let onTap {
                Button(action: onTap) { cellContent.contentShape(.rect) }
                    .buttonStyle(.plain)
            } else {
                cellContent
            }
        }
        .frame(maxWidth: .infinity)
        // VoiceOver: «Serie 1, 10 repeticiones, objetivo cumplido» en un solo elemento (sin esto
        // leía «S1» y «10» por separado).
        .accessibilityElement(children: .combine)
        .accessibilityLabel(CardAccessibilityText.seriesLabel(index))
        .accessibilityValue(CardAccessibilityText.seriesValue(cell.value, target: targetReps, hasError: cell.hasError))
        .accessibilityAddTraits(cell.isFocused ? .isSelected : [])
        .accessibilityIdentifier("series-\(index)")
    }

    private var cellContent: some View {
        VStack(spacing: 3) {
            Text(cell.label).scaledFont(11).foregroundStyle(Theme.textSecondary)
            valueText
        }
    }

    private var valueText: some View {
        Text(cell.text)
            .scaledFont(13, .semibold)
            .foregroundStyle(colors.text)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(colors.background, in: .rect(cornerRadius: Theme.radiusTag))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radiusTag)
                    .strokeBorder(cell.isFocused ? Theme.text : colors.border, lineWidth: cell.isFocused ? 2 : 1)
            }
    }

    private var colors: (text: Color, background: Color, border: Color) {
        if cell.hasError { return (Theme.dangerText, Theme.dangerTint, Theme.danger) }
        switch cell.state {
        case .done: return (Theme.accentSoft, Theme.accentTint, Theme.accent.opacity(0.5))
        case .filled: return (Theme.below, Theme.belowTint, Theme.below.opacity(0.5))
        case .empty: return (Theme.text, Theme.input, Theme.border)
        }
    }
}

/// Un chip de reps (`.chip-strip .chip`): naranja por debajo del objetivo, azul en el objetivo y
/// azul más fuerte por encima, que no es un error (en la PWA, verde y rojo); el elegido, relleno.
struct ChipButtonStyle: ButtonStyle {
    let chip: ExerciseCard.Chip

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaledFont(13, .semibold)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: 32)
            .background(background, in: .rect(cornerRadius: Theme.radiusTag))
            .overlay { RoundedRectangle(cornerRadius: Theme.radiusTag).strokeBorder(chip.isCurrent ? border : border.opacity(0.3)) }
            .frame(minHeight: TouchTarget.minimum)
            .contentShape(.rect)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }

    private var color: Color {
        switch chip.relation {
        case .below: Theme.below
        case .atTarget: Theme.accentSoft
        case .above: Theme.aboveText
        }
    }

    private var border: Color {
        chip.relation == .above ? Theme.accent : color
    }

    /// Por encima, siempre con algo de fondo: es lo que lo separa del azul del objetivo.
    private var background: Color {
        switch chip.relation {
        case .above: chip.isCurrent ? Theme.aboveTint : Theme.accentTint
        case .below, .atTarget: chip.isCurrent ? color.opacity(0.15) : .clear
        }
    }
}
