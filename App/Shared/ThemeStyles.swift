import SwiftUI

// Los estilos de la PWA en el iPhone (tarjetas, filas, botones). Los colores están en Theme.swift,
// que comparte la app del reloj.

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
        font(.system(size: 10, weight: .medium))
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
            .font(.system(size: 15, weight: .semibold))
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
