import Presentation
import SwiftUI

// Los estilos de la PWA en el iPhone (tarjetas, filas, botones). Los colores están en Theme.swift,
// que comparte la app del reloj.

extension View {
    /// `.card` de la PWA: superficie, borde fino y radio 14. Con `stripe`, el filete de 3 px a la
    /// izquierda del color del día.
    func card(padding: CGFloat = 16, background: Color = Theme.surface, border: Color = Theme.border, stripe: Color? = nil) -> some View {
        modifier(CardStyle(padding: padding, background: background, border: border, stripe: stripe))
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
            .background { ScreenBackground() }
    }

    /// Etiqueta de sección de la PWA: mayúsculas pequeñas, en gris.
    func sectionLabelStyle() -> some View {
        scaledFont(10, .medium)
            .textCase(.uppercase)
            .tracking(0.4)
            .foregroundStyle(Theme.textSecondary)
    }
}

/// La tarjeta según el estilo (`DesignStyle`).
private struct CardStyle: ViewModifier {
    @Environment(\.designStyle) private var style
    let padding: CGFloat
    let background: Color
    let border: Color
    let stripe: Color?

    /// Las esquinas de las celdas de iOS 26, más redondas que las de la PWA.
    private static let iosRadius: CGFloat = 24

    @ViewBuilder
    func body(content: Content) -> some View {
        let padded = content
            .padding(padding)
            .padding(.leading, style == .pwa || stripe == nil ? 0 : 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        switch style {
        case .pwa:
            padded
                .background(background)
                .overlay(alignment: .leading) {
                    if let stripe { Rectangle().fill(stripe).frame(width: 3) }
                }
                .clipShape(.rect(cornerRadius: Theme.radius))
                .overlay { RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(border) }
        case .nativo:
            padded
                .overlay(alignment: .leading) { stripePill }
                .background(nativeFill, in: .rect(cornerRadius: Self.iosRadius, style: .continuous))
        case .cristal, .ambiente:
            padded
                .overlay(alignment: .leading) { stripePill }
                .glassEffect(.regular.tint(glassTint), in: .rect(cornerRadius: Self.iosRadius, style: .continuous))
        }
    }

    /// El color del día como una píldora separada del borde, en vez del filete pegado.
    @ViewBuilder
    private var stripePill: some View {
        if let stripe {
            Capsule().fill(stripe).frame(width: 4).padding(.vertical, 14).padding(.leading, 9)
        }
    }

    /// Un poco más clara que la de la PWA, como las celdas agrupadas de iOS en oscuro; las tintadas
    /// (saltada, sin terminar) conservan su tinte.
    private var nativeFill: Color {
        background == Theme.surface ? Color(hex: 0x1F2129) : background
    }

    /// El cristal toma el color del día (o el tinte de la tarjeta) muy suave.
    private var glassTint: Color? {
        if let stripe { return stripe.opacity(0.10) }
        return background == Theme.surface ? nil : background
    }
}

/// El fondo de las pantallas: el de la PWA y, en `ambiente`, con los colores de los días difuminados.
private struct ScreenBackground: View {
    @Environment(\.designStyle) private var style

    var body: some View {
        ZStack {
            Theme.background
            if style == .ambiente {
                RadialGradient(colors: [Theme.color(.day1)!.opacity(0.22), .clear], center: .topLeading, startRadius: 0, endRadius: 420)
                RadialGradient(colors: [Theme.color(.day2)!.opacity(0.14), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 460)
                RadialGradient(colors: [Theme.color(.day3)!.opacity(0.08), .clear], center: .trailing, startRadius: 0, endRadius: 300)
            }
        }
        .ignoresSafeArea()
    }
}

/// Una tarjeta que se toca entera (rutina, sesión del historial): en la PWA se apaga al pulsar,
/// como `.plain`; en los estilos de iOS se hunde un poco y se ilumina, como las celdas de iOS.
struct CardButtonStyle: ButtonStyle {
    @Environment(\.designStyle) private var style

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        if style == .pwa {
            configuration.label.opacity(configuration.isPressed ? 0.7 : 1)
        } else {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .brightness(configuration.isPressed ? 0.06 : 0)
                .animation(.spring(duration: 0.25), value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == CardButtonStyle {
    static var cardPress: CardButtonStyle { CardButtonStyle() }
}

/// Botones de la PWA: píldoras. `primary` en azul con texto oscuro, `secondary` en superficie con
/// borde, `subtle` en azul suave y `danger` en rojo suave.
struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, subtle, danger }
    var kind: Kind = .primary
    @Environment(\.designStyle) private var style

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .scaledFont(15, .semibold)
            .padding(.vertical, style == .pwa ? 10 : 14)
            .padding(.horizontal, style == .pwa ? 16 : 20)
            .foregroundStyle(foreground)
            .contentShape(.capsule)
        switch style {
        case .pwa:
            label
                .background(background, in: .capsule)
                .overlay { Capsule().strokeBorder(border) }
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
        case .nativo:
            // Como `.borderedProminent` y `.bordered` de iOS: relleno, sin borde.
            label
                .background(nativeBackground, in: .capsule)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .brightness(configuration.isPressed ? 0.08 : 0)
        case .cristal, .ambiente:
            // Como `.glassProminent` y `.glass`: cristal teñido que reacciona al dedo.
            label.glassEffect(.regular.tint(glassTint).interactive(), in: .capsule)
        }
    }

    private var nativeBackground: Color {
        switch kind {
        case .primary: Theme.accent
        case .secondary: Color.white.opacity(0.10)
        case .subtle: Theme.accent.opacity(0.20)
        case .danger: Theme.red.opacity(0.20)
        }
    }

    private var glassTint: Color? {
        switch kind {
        case .primary: Theme.accent
        case .secondary: nil
        case .subtle: Theme.accent.opacity(0.30)
        case .danger: Theme.red.opacity(0.30)
        }
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
