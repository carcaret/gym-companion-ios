import SwiftUI

/// Lo que se abre y se cierra (tarjetas de ejercicio, filas de Progreso): se toca toda la cabecera,
/// la flecha de iOS gira hacia abajo al abrir, el contenido entra deslizándose y VoiceOver dice si
/// está desplegado (antes decía «seleccionado»). No es `DisclosureGroup`: dentro de una fila de
/// `List` (el entreno en curso) la cabecera y el contenido se pintaban uno encima de otro (captura
/// del CI, 2026-10-26).
struct CardDisclosure<Label: View, Content: View>: View {
    @Environment(\.disclosureAnimatesHeight) private var animatesHeight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                if Variant.current == "sin-offset" || Variant.current == "por-valor" {
                    content.transition(.opacity)
                } else if animatesHeight {
                    content.transition(.opacity.combined(with: .offset(y: -8)))
                } else {
                    // Con su propia animación: solo la opacidad, la fila cambia de golpe.
                    content.transition(reduceMotion ? .identity : .opacity.animation(.easeOut(duration: 0.2)))
                }
            }
        }
    }
}

extension EnvironmentValues {
    /// Si abrir y cerrar anima la altura. En una fila de `List` no: la lista coloca el contenido
    /// de la fila más abajo mientras la hace crecer, y la cabecera pasaba por encima de él (en el
    /// simulador se quedaba así varios segundos; vídeo del CI, 2026-10-27). Ahí la fila cambia de
    /// golpe y el contenido entra con un fundido. Lo apagan el entreno y Progreso.
    @Entry var disclosureAnimatesHeight = true
}

/// Prueba visual: la variante que pide el test (`-variante`).
enum Variant {
    static let current: String = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-variante"), index + 1 < arguments.count else { return "pr" }
        return arguments[index + 1]
    }()
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
    @Environment(\.disclosureAnimatesHeight) private var animatesHeight

    var body: some View {
        // Con animación, la tarjeta crece con el muelle de iOS y la flecha gira a la vez. En una
        // `List` (`disclosureAnimatesHeight`), la fila cambia de golpe y solo gira la flecha.
        let button = Button {
            if Variant.current == "por-valor" {
                toggle()
            } else if animatesHeight {
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
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(animatesHeight || reduceMotion ? nil : .snappy, value: isExpanded)
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
