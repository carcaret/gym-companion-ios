import SwiftUI

// Las tarjetas, las filas y el fondo de la PWA en el iPhone. Los colores están en Theme.swift, que
// comparte la app del reloj.

extension View {
    /// `.card` de la PWA con las esquinas de las listas de iOS 26 y sin borde, como las secciones
    /// nativas. `border` solo cuando el borde dice algo (una sesión sin terminar). Con `stripe`, el
    /// filete de 3 px a la izquierda del color del día.
    func card(padding: CGFloat = 16, background: Color = Theme.surface, border: Color? = nil, stripe: Color? = nil) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .overlay(alignment: .leading) {
                if let stripe { Rectangle().fill(stripe).frame(width: 3) }
            }
            .clipShape(.rect(cornerRadius: Theme.radius))
            .overlay {
                if let border { RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(border) }
            }
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
        scaledFont(11, .medium)
            .textCase(.uppercase)
            .tracking(0.4)
            .foregroundStyle(Theme.textSecondary)
    }
}
