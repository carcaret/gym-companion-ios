import Presentation
import SwiftUI

/// El estilo de la PWA (`index.css`): tema oscuro con la paleta tipo VS Code, tarjetas separadas
/// con borde fino y el color de cada día. La app va siempre en oscuro.
enum Theme {
    // Fondos y superficies
    static let background = Color(hex: 0x0F0F11)      // --bg-deep
    static let surface = Color(hex: 0x181A20)         // --surface: tarjeta
    static let surface2 = Color(hex: 0x1E2028)        // --surface-2: anidada o elevada
    static let cardSolid = Color(hex: 0x1C1E26)       // --bg-card-solid
    static let input = Color.white.opacity(0.05)      // --bg-input
    static let border = Color.white.opacity(0.09)     // --border
    static let borderLight = Color.white.opacity(0.06)
    static let borderStrong = Color.white.opacity(0.16)

    // Texto
    static let text = Color(hex: 0xD4D4D4)
    static let textSecondary = Color(hex: 0xD4D4D4).opacity(0.6)
    static let textMuted = Color(hex: 0xD4D4D4).opacity(0.35)

    // Colores
    static let accent = Color(hex: 0x569CD6)
    static let accentLight = Color(hex: 0x9CDCFE)
    static let accentSoft = Color(hex: 0x93C5EA)
    static let accentTint = Color(hex: 0x569CD6).opacity(0.15)
    static let green = Color(hex: 0x6A9955)
    static let greenSoft = Color(hex: 0x5DCAA5)
    static let greenTint = Color(hex: 0x5DCAA5).opacity(0.15)
    static let red = Color(hex: 0xF44747)
    static let redSoft = Color(hex: 0xE2706A)
    static let redTint = Color(hex: 0xF44747).opacity(0.12)
    static let skipTint = Color(hex: 0xF44747).opacity(0.06)
    static let danger = Color(hex: 0xD97070)
    static let dangerTint = Color(hex: 0xD97070).opacity(0.15)
    static let orange = Color(hex: 0xCE9178)
    static let gold = Color(hex: 0xDCDCAA)
    static let focus = Color(hex: 0xE8B84B)           // la serie que se está editando

    // Radios
    static let radius: CGFloat = 14
    static let radiusSmall: CGFloat = 10
    static let radiusTag: CGFloat = 6

    /// `--color-dia1..3`.
    static func color(_ tint: RoutineTint?) -> Color? {
        switch tint {
        case .day1: Color(hex: 0x7AAEE0)
        case .day2: Color(hex: 0x7FCAB1)
        case .day3: Color(hex: 0xCABE7A)
        case nil: nil
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

extension View {
    /// `.card` de la PWA: superficie, borde fino y radio 14. Con `stripe`, el filete de 3 px a la
    /// izquierda del color del día.
    func card(padding: CGFloat = 16, background: Color = Theme.surface, border: Color = Theme.border, stripe: Color? = nil) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .overlay(alignment: .leading) {
                if let stripe { Rectangle().fill(stripe).frame(width: 3) }
            }
            .clipShape(.rect(cornerRadius: Theme.radius))
            .overlay { RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(border) }
    }

    /// Una fila de `List` que es una tarjeta suelta: sin fondo ni separador, con 12 px entre
    /// tarjetas. Así se conservan los gestos de la lista (deslizar, arrastrar).
    func cardRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }

    /// El fondo de la PWA detrás de una pantalla (y de su `List` o `Form`).
    func screenBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.background)
    }

    /// Etiqueta de sección de la PWA: mayúsculas pequeñas, en gris.
    func sectionLabelStyle() -> some View {
        scaledFont(10, .medium)
            .textCase(.uppercase)
            .tracking(0.4)
            .foregroundStyle(Theme.textSecondary)
    }
}

/// Botones de la PWA: píldoras. `primary` en azul con texto oscuro, `secondary` en superficie con
/// borde, `subtle` en azul suave y `danger` en rojo suave.
struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, subtle, danger }
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaledFont(15, .semibold)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .foregroundStyle(foreground)
            .background(background, in: .capsule)
            .overlay { Capsule().strokeBorder(border) }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .contentShape(.capsule)
    }

    private var foreground: Color {
        switch kind {
        case .primary: Color(hex: 0x08121C)
        case .secondary: Theme.text
        case .subtle: Theme.accentLight
        case .danger: Theme.redSoft
        }
    }

    private var background: Color {
        switch kind {
        case .primary: Theme.accent
        case .secondary: Theme.surface2
        case .subtle: Theme.accent.opacity(0.12)
        case .danger: Theme.redTint
        }
    }

    private var border: Color {
        switch kind {
        case .primary: .clear
        case .secondary: Theme.border
        case .subtle: Theme.accent.opacity(0.25)
        case .danger: Theme.red.opacity(0.28)
        }
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static func pill(_ kind: PillButtonStyle.Kind = .primary) -> PillButtonStyle { PillButtonStyle(kind: kind) }
}

extension View {
    /// La letra del sistema al tamaño de la PWA, que crece y mengua con la letra del iPhone
    /// (Dynamic Type). Con el tamaño normal mide lo mismo que `.font(.system(size:))`, que no
    /// escala: no se usa en ninguna vista.
    func scaledFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> some View {
        modifier(ScaledFont(size: size, weight: weight))
    }
}

private struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: Self.style(for: size))
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }

    /// El estilo de iOS de tamaño más parecido, para que crezca a su ritmo: los pequeños crecen
    /// menos que el cuerpo del texto.
    private static func style(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<11.5: .caption2
        case ..<12.5: .caption
        case ..<14.5: .footnote
        case ..<15.5: .subheadline
        case ..<16.5: .callout
        case ..<19: .body
        default: .title3
        }
    }
}
