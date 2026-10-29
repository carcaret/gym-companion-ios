import SwiftUI

/// El botón de la PWA dentro del contenido: una píldora azul con el texto oscuro.
struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaledFont(15, .semibold)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .frame(minHeight: TouchTarget.minimum)  // medía 40 (repaso de la HIG, 2026-10-28)
            .foregroundStyle(Theme.onAccent)
            .background(Theme.accent, in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .contentShape(.capsule)
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static var pill: PillButtonStyle { PillButtonStyle() }
}

/// Las píldoras que flotan sobre el contenido (los botones fijos de abajo, `BottomActions`): de
/// cristal, como la barra de pestañas que tienen debajo, con los colores de la PWA. La principal,
/// teñida de azul y con el texto oscuro (el blanco que pone iOS no gustaba, decisión del usuario,
/// 2026-10-27); la secundaria, cristal sin teñir con el texto en azul claro. `interactive()`: al
/// tocarla reacciona como los botones de cristal de iOS. Miden 50 pt de alto como poco, los
/// botones grandes de iOS (repaso de la HIG, 2026-10-28: medían 40, menos que los 44 de una zona
/// de toque), y crecen con la letra.
struct GlassPillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    var kind: Kind = .primary

    static let minimumHeight: CGFloat = 50

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaledFont(15, .semibold)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .frame(minHeight: Self.minimumHeight)
            .foregroundStyle(kind == .primary ? Theme.onAccent : Theme.accentLight)
            .contentShape(.capsule)
            .glassEffect(kind == .primary ? .regular.tint(Theme.accent).interactive() : .regular.interactive(), in: .capsule)
    }
}

extension ButtonStyle where Self == GlassPillButtonStyle {
    static func glassPill(_ kind: GlassPillButtonStyle.Kind = .primary) -> GlassPillButtonStyle { GlassPillButtonStyle(kind: kind) }
}

/// Una tarjeta que se toca entera (rutinas de Hoy, sesiones del Historial): mientras el dedo está
/// apoyado, se oscurece y se encoge un pelín, y abre al soltar, sin esperar a ninguna animación
/// (repaso de la HIG, 2026-10-28; antes, un círculo que nacía del dedo, el efecto de Android, y la
/// acción esperaba a que llenase la tarjeta). En una `List`, un toque muy rápido no llega a marcarse
/// como pulsado: es lo que hacen las filas de iOS. El label ya lleva su `.card()`.
struct CardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? -0.06 : 0)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CardButtonStyle {
    static var card: CardButtonStyle { CardButtonStyle() }
}

/// Mientras el dedo está apoyado, la cabecera se apaga un poco: Apple pide que todo botón propio se
/// vea pulsado (repaso de la HIG, 2026-10-28). Sin animación: con `.plain`, el texto volvía con un
/// fundido después de abrirse la tarjeta, un parpadeo en cada toque (vídeo del CI, 2026-10-27).
struct DimmedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(nil, value: configuration.isPressed)
    }
}
