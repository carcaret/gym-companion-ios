import SwiftUI

/// Lo que se abre y se cierra (`DisclosureGroup`: tarjetas de ejercicio, filas de Progreso) con el
/// aspecto de la app: se toca toda la cabecera, la flecha de iOS gira hacia abajo al abrir y
/// VoiceOver dice si está desplegado (antes decía «seleccionado»).
struct CardDisclosureStyle: DisclosureGroupStyle {
    var chevronSize: CGFloat = 13
    /// Para los tests: va en el botón de la cabecera.
    var identifier: String?

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureHeader(isExpanded: configuration.isExpanded, chevronSize: chevronSize, identifier: identifier,
                             toggle: { withAnimation(.snappy) { configuration.isExpanded.toggle() } }) {
                configuration.label
            }
            if configuration.isExpanded { configuration.content }
        }
    }
}

extension DisclosureGroupStyle where Self == CardDisclosureStyle {
    static func card(chevronSize: CGFloat = 13, identifier: String? = nil) -> CardDisclosureStyle {
        CardDisclosureStyle(chevronSize: chevronSize, identifier: identifier)
    }
}

/// La cabecera de `CardDisclosureStyle`, también suelta para lo que al abrirse enseña más de lo
/// mismo en vez de algo escondido (la lista de ejercicios de Progreso).
struct DisclosureHeader<Label: View>: View {
    let isExpanded: Bool
    var chevronSize: CGFloat = 13
    var identifier: String?
    let toggle: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        let button = Button(action: toggle) {
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

extension Binding where Value == Bool {
    /// Abierto según el modelo; al tocar, se le pide que cambie.
    init(isOpen: Bool, toggle: @escaping () -> Void) {
        self.init(get: { isOpen }, set: { if $0 != isOpen { toggle() } })
    }
}
