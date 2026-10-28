import SwiftUI

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
