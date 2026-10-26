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

/// Una tarjeta que se toca entera (rutinas de Hoy, sesiones del Historial): al apoyar el dedo se
/// rellena de blanco de izquierda a derecha y se encoge un pelín; al soltar, el velo se desvanece.
/// El label ya lleva su `.card()`.
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressableCard(label: configuration.label, isPressed: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CardButtonStyle {
    static var card: CardButtonStyle { CardButtonStyle() }
}

private struct PressableCard: View {
    let label: ButtonStyleConfiguration.Label
    let isPressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Lo barrido (0…1) y lo que queda del velo (0…1).
    @State private var sweep: CGFloat = 0
    @State private var veil: Double = 0
    @State private var pressedAt = Date.distantPast
    /// Cuenta las pulsaciones, para que el final de un desvanecido no borre el barrido de la siguiente.
    @State private var presses = 0

    /// 120 ms: rápido, pero se llega a ver (decisión del usuario, 2026-10-26).
    private static let sweepDuration = 0.12
    private static let fadeDuration = 0.26

    var body: some View {
        label
            .overlay {
                Rectangle()
                    .fill(Color.white.opacity(0.07 * veil))
                    .scaleEffect(x: sweep, y: 1, anchor: .leading)
                    .allowsHitTesting(false)
            }
            .clipShape(.rect(cornerRadius: Theme.radius))
            .scaleEffect(isPressed && !reduceMotion ? 0.985 : 1)
            .animation(.easeOut(duration: Self.sweepDuration), value: isPressed)
            .onChange(of: isPressed) { _, pressed in
                if pressed { press() } else { release() }
            }
    }

    private func press() {
        presses += 1
        pressedAt = .now
        veil = 1
        sweep = 0
        withAnimation(reduceMotion ? nil : .easeOut(duration: Self.sweepDuration)) { sweep = 1 }
    }

    /// Un toque rápido suelta antes de que acabe el barrido: el velo espera a que llegue al final.
    private func release() {
        let press = presses
        let pending = max(0, Self.sweepDuration - Date.now.timeIntervalSince(pressedAt))
        withAnimation(.easeOut(duration: Self.fadeDuration).delay(pending)) {
            veil = 0
        } completion: {
            if press == presses { sweep = 0 }
        }
    }
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
