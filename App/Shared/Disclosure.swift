import SwiftUI

/// Lo que se abre y se cierra (tarjetas de ejercicio, filas de Progreso): se toca toda la cabecera,
/// la flecha de iOS gira hacia abajo al abrir, el contenido entra deslizándose y VoiceOver dice si
/// está desplegado (antes decía «seleccionado»). No es `DisclosureGroup`: dentro de una fila de
/// `List` (el entreno en curso) la cabecera y el contenido se pintaban uno encima de otro (captura
/// del CI, 2026-10-26).
struct CardDisclosure<Label: View, Content: View>: View {
    let isExpanded: Bool
    var chevronSize: CGFloat = 13
    /// Para los tests: va en el botón de la cabecera.
    var identifier: String?
    let toggle: () -> Void
    @ViewBuilder let label: Label
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureHeader(isExpanded: isExpanded, chevronSize: chevronSize, identifier: identifier, toggle: toggle) {
                label
            }
            if isExpanded {
                content.transition(.opacity.combined(with: .offset(y: -8)))
            }
        }
    }
}

/// La cabecera de `CardDisclosure`, también suelta para lo que al abrirse enseña más de lo mismo
/// en vez de algo escondido (la lista de ejercicios de Progreso).
struct DisclosureHeader<Label: View>: View {
    let isExpanded: Bool
    var chevronSize: CGFloat = 13
    var identifier: String?
    let toggle: () -> Void
    @ViewBuilder let label: Label
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Con animación, la tarjeta (o la fila de la lista) crece con el muelle de iOS y la flecha
        // gira a la vez.
        let button = Button { withAnimation(reduceMotion ? nil : .snappy) { toggle() } } label: {
            HStack(spacing: 10) {
                label
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .scaledFont(chevronSize, .semibold)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .foregroundStyle(Theme.textMuted)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isExpanded ? Text("Desplegado") : Text("Plegado"))
        if let identifier {
            button.accessibilityIdentifier(identifier)
        } else {
            button
        }
    }
}
