import Presentation
import SwiftUI

/// Lo que se abre y se cierra (tarjetas de ejercicio, filas de Progreso): se toca toda la cabecera,
/// la flecha de iOS gira hacia abajo al abrir, el contenido entra deslizándose y VoiceOver dice si
/// está desplegado (antes decía «seleccionado»). No es `DisclosureGroup`: dentro de una fila de
/// `List` (el entreno en curso) la cabecera y el contenido se pintaban uno encima de otro (captura
/// del CI, 2026-10-26).
struct CardDisclosure<Label: View, Content: View>: View {
    @Environment(\.disclosureAnimates) private var animates
    let isExpanded: Bool
    var chevronSize: CGFloat = 13
    /// Para los tests: va en el botón de la cabecera.
    var identifier: String?
    /// El margen de la cabecera, dentro de su zona de toque (en Progreso, el de la fila).
    var headerPadding = EdgeInsets()
    let toggle: () -> Void
    @ViewBuilder let label: Label
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureHeader(isExpanded: isExpanded, chevronSize: chevronSize, identifier: identifier, padding: headerPadding, toggle: toggle) {
                label
            }
            if isExpanded {
                if animates {
                    content.transition(.opacity)
                } else {
                    content
                }
            }
        }
    }
}

extension EnvironmentValues {
    /// Si abrir y cerrar se anima. En una fila de `List` (el entreno) no: con animación, la lista
    /// daba a la fila su altura nueva pero seguía pintando la tarjeta a su tamaño de antes, centrada,
    /// con la cabecera encima del contenido (captura y vídeos del CI, 2026-10-27). Ahí se abre y se
    /// cierra de golpe, y solo gira la flecha.
    @Entry var disclosureAnimates = true
}

/// La cabecera de `CardDisclosure`, también suelta para lo que al abrirse enseña más de lo mismo
/// en vez de algo escondido (la lista de ejercicios de Progreso).
struct DisclosureHeader<Label: View>: View {
    let isExpanded: Bool
    var chevronSize: CGFloat = 13
    var identifier: String?
    /// Dentro del botón: la fila entera se toca, no solo el texto.
    var padding = EdgeInsets()
    var minHeight = TouchTarget.minimum
    let toggle: () -> Void
    @ViewBuilder let label: Label
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.disclosureAnimates) private var animates

    var body: some View {
        // Con animación, la tarjeta crece con el muelle de iOS y la flecha gira a la vez. Sin ella
        // (`disclosureAnimates`, en una `List`), solo gira la flecha.
        let button = Button {
            if animates {
                withAnimation(reduceMotion ? nil : .snappy) { toggle() }
            } else {
                toggle()
            }
        } label: {
            HStack(spacing: 10) {
                label
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .scaledFont(chevronSize, .semibold)
                    // Solo el giro: con `.animation(_:value:)` también se animaba su posición, y en
                    // la `List` la flecha se quedaba a medio camino, lejos de la cabecera.
                    .animation(animates || reduceMotion ? nil : .snappy) { $0.rotationEffect(.degrees(isExpanded ? 90 : 0)) }
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(padding)
            .frame(minHeight: minHeight)
            .contentShape(.rect)
        }
        .buttonStyle(DimmedButtonStyle())
        .accessibilityValue(isExpanded ? CardAccessibilityText.expanded : CardAccessibilityText.collapsed)
        if let identifier {
            button.accessibilityIdentifier(identifier)
        } else {
            button
        }
    }
}

/// Mientras el dedo está apoyado, la cabecera se apaga un poco: Apple pide que todo botón propio se
/// vea pulsado (repaso de la HIG, 2026-10-28). Sin animación: con `.plain`, el texto volvía con un
/// fundido después de abrirse la tarjeta, un parpadeo en cada toque (vídeo del CI, 2026-10-27).
private struct DimmedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(nil, value: configuration.isPressed)
    }
}
